`timescale 1ns/1ps

module PRT #(
  parameter DATA_WIDTH = 8,           // Data bus width (1 byte)
  parameter MEM_DEPTH  = 1518,         // Maximum number of words per packet (e.g., full Ethernet frame)
  parameter NUM_SLOTS  = 10            // Number of available packet storage slots
) (
  input  logic                          CLK,
  input  logic                          RST_N,

  //====================================
  // -------- Write Transaction --------
  //====================================
  // Start transaction: a free slot is allocated and its write pointer and counters are initialized.
  input  logic                          EN_start_writing_prt_entry,
  output logic                          RDY_start_writing_prt_entry,
  output logic [$clog2(NUM_SLOTS)-1:0]  start_writing_prt_entry,

  // Data transfer: while EN_write_prt_entry is high, one data byte is written per clock cycle.
  input  logic                          EN_write_prt_entry,
  output logic                          RDY_write_prt_entry,
  input  logic [DATA_WIDTH-1:0]         write_prt_entry_data,

  // Finish transaction: asserts a one-cycle ready pulse when the write is finalized.
  input  logic                          EN_finish_writing_prt_entry,
  output logic                          RDY_finish_writing_prt_entry,
  

  //====================================
  // ----- Invalidate Transaction ------
  //====================================
  // Specify and begin invalidating a slot.
  input  logic                          EN_invalidate_prt_entry,
  output logic                          RDY_invalidate_prt_entry,
  input  logic [$clog2(NUM_SLOTS)-1:0]  invalidate_prt_entry_slot,

  
  //====================================
  // -------- Read Transaction ---------
  //====================================
  // Start read: select a slot to read and initialize its read pointer.
  input  logic                          EN_start_reading_prt_entry,
  output logic                          RDY_start_reading_prt_entry,
  input  logic [$clog2(NUM_SLOTS)-1:0]  start_reading_prt_entry_slot,

  // Data transfer: while EN_read_prt_entry is high, one byte is output per clock cycle.
  input  logic                          EN_read_prt_entry,
  output logic                          RDY_read_prt_entry,
  // The read bus is DATA_WIDTH+1 bits wide. The extra MSB indicates if the read is complete.
  output logic [DATA_WIDTH:0]           read_prt_entry,
  
  //====================================
  // --------- Free Slot Check ---------
  //====================================
  // Indicates if at least one PRT slot is free.
  output logic                          is_prt_slot_free,
  output logic                          RDY_is_prt_slot_free
);

  //====================================================================
  // FSM State Definitions
  //====================================================================
  typedef enum logic [2:0] {
    S_IDLE,            // Waiting for any enable signal
    S_WRITE_START,     // Allocate a free slot and initialize write pointers/counters
    S_WRITE,           // Write packet data byte-by-byte
    S_WRITE_FINISH,    // Finalize writing: mark the packet as complete and valid
    S_READ_START,      // Initialize pointers for reading from a slot
    S_READ,            // Read packet data byte-by-byte
    S_INVALIDATE_INIT, // Initialize invalidation (clear) of a slot
    S_INVALIDATE_RUN   // Sequentially clear the slot memory
  } state_t;
  
  state_t state, next_state;

  // "state_entry" is a one–cycle pulse asserted when a state transition occurs.
  logic state_entry;
  always_ff @(posedge CLK or negedge RST_N) begin
    if (!RST_N)
      state_entry <= 1'b0;
    else if (state != next_state)
      state_entry <= 1'b1;
    else
      state_entry <= 1'b0;
  end

  //====================================================================
  // Per–Slot Registers and Memory
  //====================================================================
  // Metadata signals for each slot
  logic        valid          [NUM_SLOTS-1:0];
  logic [15:0] bytes_rcvd     [NUM_SLOTS-1:0];
  logic [15:0] bytes_sent     [NUM_SLOTS-1:0];
  logic        frame_complete [NUM_SLOTS-1:0];
  
  // Write and read pointers (addressing up to MEM_DEPTH locations)
  logic [$clog2(MEM_DEPTH)-1:0] write_ptr [NUM_SLOTS-1:0];
  logic [$clog2(MEM_DEPTH)-1:0] read_ptr  [NUM_SLOTS-1:0];
  
  // 2D memory array for storing packet data (header + payload)
  logic [DATA_WIDTH-1:0] prt_table [NUM_SLOTS-1:0][0:MEM_DEPTH-1];
  
  // Pointer for invalidation (clearing a slot)
  logic [$clog2(MEM_DEPTH)-1:0] invalidate_ptr;
  
  // current_slot holds the slot number currently accessed for writing or reading.
  logic [$clog2(NUM_SLOTS)-1:0] current_slot;

  //====================================================================
  // Free Slot Selection (Combinational)
  //====================================================================
  // Scan through the NUM_SLOTS to choose the first slot that is not valid.
  logic [$clog2(NUM_SLOTS)-1:0] free_slot;
  logic                         free_available;
  integer idx;
  always_comb begin
    free_slot      = '0;
    free_available = 1'b0;
    for (idx = 0; idx < NUM_SLOTS; idx = idx + 1) begin
      if (!valid[idx] && !free_available) begin
        free_slot      = idx;
        free_available = 1'b1;
      end
    end
  end

  assign is_prt_slot_free    = free_available;
  assign RDY_is_prt_slot_free = 1'b1;  // Always ready

  //====================================================================
  // FSM: Sequential State and Register Updates
  //====================================================================
  integer i, j;
  always_ff @(posedge CLK or negedge RST_N) begin
    if (!RST_N) begin
      state          <= S_IDLE;
      current_slot   <= '0;
      invalidate_ptr <= '0;
      // Initialize all per-slot registers and clear the memory.
      for (i = 0; i < NUM_SLOTS; i = i + 1) begin
        valid[i]          <= 1'b0;
        bytes_rcvd[i]     <= 16'd0;
        bytes_sent[i]     <= 16'd0;
        frame_complete[i] <= 1'b0;
        write_ptr[i]      <= '0;
        read_ptr[i]       <= '0;
        for (j = 0; j < MEM_DEPTH; j = j + 1) begin
          prt_table[i][j] <= '0;
        end
      end
    end else begin
      state <= next_state;
      case (state)
        //----- Write Transaction -----
        S_WRITE_START: begin
          // Allocate the free slot and initialize write pointers and counters.
          current_slot              <= free_slot;
          write_ptr[free_slot]      <= '0;
          bytes_rcvd[free_slot]     <= 16'd0;
          bytes_sent[free_slot]     <= 16'd0;
          frame_complete[free_slot] <= 1'b0;
        end

        S_WRITE: begin
          // When enabled, write one data byte per clock cycle.
          if (EN_write_prt_entry) begin
            prt_table[current_slot][ write_ptr[current_slot] ] <= write_prt_entry_data;
            write_ptr[current_slot]                            <= write_ptr[current_slot] + 1;
            bytes_rcvd[current_slot]                           <= bytes_rcvd[current_slot] + 1;
          end
        end

        S_WRITE_FINISH: begin
          // Finalize the write transaction.
          frame_complete[current_slot] <= 1'b1;
          valid[current_slot]          <= 1'b1;
        end

        //----- Read Transaction -----
        S_READ_START: begin
          // Select the requested slot and initialize read pointers.
          current_slot             <= start_reading_prt_entry_slot;
          read_ptr[current_slot]   <= '0;
          bytes_sent[current_slot] <= 16'd0;
        end

        S_READ: begin
          // When enabled, read one data byte per clock cycle.
          if (EN_read_prt_entry) begin
            read_ptr[current_slot]   <= read_ptr[current_slot] + 1;
            bytes_sent[current_slot] <= bytes_sent[current_slot] + 1;
          end
        end

        //----- Invalidate Transaction -----
        S_INVALIDATE_INIT: begin
          // Initialize the invalidation pointer.
          invalidate_ptr <= '0;
        end

        S_INVALIDATE_RUN: begin
          // Clear the targeted slot word-by-word.
          prt_table[invalidate_prt_entry_slot][invalidate_ptr] <= '0;
          if (invalidate_ptr == MEM_DEPTH - 1) begin
            valid[invalidate_prt_entry_slot]          <= 1'b0;
            bytes_rcvd[invalidate_prt_entry_slot]     <= 16'd0;
            bytes_sent[invalidate_prt_entry_slot]     <= 16'd0;
            frame_complete[invalidate_prt_entry_slot] <= 1'b0;
          end
          invalidate_ptr <= invalidate_ptr + 1;
        end

        default: ;  // No updates needed in S_IDLE
      endcase
    end
  end

  //====================================================================
  // FSM: Next State Combinational Logic
  //====================================================================
  always_comb begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (EN_start_writing_prt_entry && is_prt_slot_free)
          next_state = S_WRITE_START;
        else if (EN_start_reading_prt_entry && valid[start_reading_prt_entry_slot])
          next_state = S_READ_START;
        else if (EN_invalidate_prt_entry)
          next_state = S_INVALIDATE_INIT;
        else
          next_state = S_IDLE;
      end

      S_WRITE_START: begin
        // Once the free slot is allocated, transition into the write state.
        next_state = S_WRITE;
      end

      S_WRITE: begin
        // Stay in the write state until either the memory is full or the finish signal is asserted.
        if ((write_ptr[current_slot] == MEM_DEPTH - 1) || EN_finish_writing_prt_entry)
          next_state = S_WRITE_FINISH;
        else
          next_state = S_WRITE;
      end

      S_WRITE_FINISH: begin
        next_state = S_IDLE;
      end

      S_READ_START: begin
        next_state = S_READ;
      end

      S_READ: begin
        // Exit the read state when reading is complete or EN_read_prt_entry is deasserted.
        if (!EN_read_prt_entry || (read_ptr[current_slot] >= bytes_rcvd[current_slot]))
          next_state = S_IDLE;
        else
          next_state = S_READ;
      end

      S_INVALIDATE_INIT: begin
        next_state = S_INVALIDATE_RUN;
      end

      S_INVALIDATE_RUN: begin
        if (invalidate_ptr == MEM_DEPTH - 1)
          next_state = S_IDLE;
        else
          next_state = S_INVALIDATE_RUN;
      end

      default: next_state = S_IDLE;
    endcase
  end

  //====================================================================
  // Ready Signal Generation (Handshake Acknowledgement)
  //====================================================================
  // For start-type transactions, a one-cycle ready pulse is issued on state entry.
  assign RDY_start_writing_prt_entry  = (state == S_WRITE_START)    ;
  assign RDY_finish_writing_prt_entry = (state == S_WRITE_FINISH)   ;
  assign RDY_start_reading_prt_entry  = (state == S_READ_START)     ;
  assign RDY_invalidate_prt_entry     = (state == S_INVALIDATE_INIT);
  
  // For data-transfer states, the ready signal is continuously asserted.
  assign RDY_write_prt_entry = (state == S_WRITE);
  assign RDY_read_prt_entry  = (state == S_READ);
  
  // The free slot that was chosen is output during a write transaction.
  assign start_writing_prt_entry = current_slot;

  //====================================================================
  // Read Data Output
  //====================================================================
  // The read bus is DATA_WIDTH+1 bits wide.
  // The MSB is set high when the read pointer equals (or exceeds) the number of received bytes.
  assign read_prt_entry = (read_ptr[current_slot] >= bytes_rcvd[current_slot]) ?
                          {1'b1, {DATA_WIDTH{1'b0}}} :
                          {1'b0, prt_table[current_slot][read_ptr[current_slot]]};

endmodule
