`timescale 1ns/1ps

module PRT #(
  parameter DATA_WIDTH = 8,           // Data bus width (1 byte)
  parameter MEM_DEPTH  = 1518,         // Maximum frame size (in bytes)
  parameter NUM_SLOTS  = 10             // Number of PRT slots
) (
  input  logic                          CLK,
  input  logic                          RST_N,
  
  // -------- Write Transaction --------
  // Step 1: Request to start writing.
  input  logic                          EN_start_writing_prt_entry,
  // On transition, the PRT returns the chosen free slot.
  output logic [$clog2(NUM_SLOTS)-1:0]  start_writing_prt_entry,
  // Ready pulse issued once the FSM enters the write-start state.
  output logic                          RDY_start_writing_prt_entry,
  
  // Step 2: Data transfer in write state.
  // While EN_write_prt_entry is high, one data byte is written per clock.
  input  logic [DATA_WIDTH-1:0]         write_prt_entry_data,
  input  logic                          EN_write_prt_entry,
  // In the write state, RDY_write_prt_entry is continuously high to acknowledge each data transfer.
  output logic                          RDY_write_prt_entry,
  
  // Step 3: Request to finish writing.
  input  logic                          EN_finish_writing_prt_entry,
  // A one–cycle ready pulse is generated when the write is finalized.
  output logic                          RDY_finish_writing_prt_entry,
  
  // -------- Invalidate Transaction --------
  // Specify which slot to invalidate.
  input  logic [$clog2(NUM_SLOTS)-1:0]  invalidate_prt_entry_slot,
  // Enable to start the invalidation transaction.
  input  logic                          EN_invalidate_prt_entry,
  // A one–cycle ready pulse is generated when the FSM enters the invalidate–start state.
  output logic                          RDY_invalidate_prt_entry,
  
  // -------- Read Transaction --------
  // Specify which slot to read from.
  input  logic [$clog2(NUM_SLOTS)-1:0]  start_reading_prt_entry_slot,
  // Enable to request a read transaction.
  input  logic                          EN_start_reading_prt_entry,
  // A one–cycle ready pulse is generated when the FSM enters the read–start state.
  output logic                          RDY_start_reading_prt_entry,
  
  // While EN_read_prt_entry is high, one data byte is read each clock.
  input  logic                          EN_read_prt_entry,
  // The output bus is DATA_WIDTH+1 bits wide. The extra MSB is a “complete” flag (1 when read is done).
  output logic [DATA_WIDTH:0]           read_prt_entry,
  // In the read state, this ready signal is continuously high to acknowledge each data transfer.
  output logic                          RDY_read_prt_entry,
  
  // -------- Free Slot Check --------
  // Indicates if at least one PRT slot is free.
  output logic                          is_prt_slot_free,
  // Always ready to provide free–slot status.
  output logic                          RDY_is_prt_slot_free
);

  //====================================================================
  // FSM State Definitions
  //====================================================================
  typedef enum logic [2:0] {
    S_IDLE,            // Waiting for any enable input
    S_WRITE_START,     // Transition into write transaction: choose free slot & initialize write pointers
    S_WRITE,           // Data transfer: write frame data byte–by–byte
    S_WRITE_FINISH,    // Finalize write: mark frame complete and valid
    S_READ_START,      // Transition into read transaction: select slot & initialize read pointers
    S_READ,            // Data transfer: output frame data byte–by–byte
    S_INVALIDATE_INIT, // Transition into invalidation: initialize pointer to clear memory
    S_INVALIDATE_RUN   // Invalidate: sequentially clear the specified slot
  } state_t;

  state_t state, next_state;

  //--------------------------------------------------------------------
  // "state_entry" is a one–cycle pulse that is high on the first cycle after a state transition.
  //--------------------------------------------------------------------
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
  // Per–Slot Registers and Memory (Frame Structure)
  //====================================================================
  // For each slot, the following registers are maintained:
  //   valid          : 1 if the slot holds a valid frame.
  //   bytes_rcvd     : counter for bytes written.
  //   bytes_sent     : counter for bytes read.
  //   frame_complete : flag set when the entire frame has been received.
  logic        valid          [NUM_SLOTS-1:0];
  logic [15:0] bytes_rcvd     [NUM_SLOTS-1:0];
  logic [15:0] bytes_sent     [NUM_SLOTS-1:0];
  logic        frame_complete [NUM_SLOTS-1:0];

  // Write and read pointers (to address MEM_DEPTH locations)
  logic [$clog2(MEM_DEPTH)-1:0] write_ptr [NUM_SLOTS-1:0];
  logic [$clog2(MEM_DEPTH)-1:0] read_ptr  [NUM_SLOTS-1:0];

  // Frame data storage: two–dimensional memory array.
  logic [DATA_WIDTH-1:0] prt_table [NUM_SLOTS-1:0][0:MEM_DEPTH-1];

  // For invalidation: pointer to clear memory sequentially.
  logic [$clog2(MEM_DEPTH)-1:0] invalidate_ptr;

  // current_slot holds the slot number currently accessed (for write or read).
  logic [$clog2(NUM_SLOTS)-1:0] current_slot;

  //====================================================================
  // Free Slot Selection (Combinational)
  //====================================================================
  // (For NUM_SLOTS==2, choose the lowest numbered slot that is not valid.)
  logic [$clog2(NUM_SLOTS)-1:0] free_slot;
  always_comb begin
    if (!valid[0])
      free_slot = 0;
    else if (!valid[1])
      free_slot = 1;
    else
      free_slot = 0; // Default (should not occur if is_prt_slot_free is true)
  end

  // A slot is free if at least one is not valid.
  assign is_prt_slot_free   = (!valid[0] || !valid[1]);
  assign RDY_is_prt_slot_free = 1'b1;  // Always ready

  //====================================================================
  // FSM: Sequential State and Register Updates
  //====================================================================
  integer i, j;
  always_ff @(posedge CLK or negedge RST_N) begin
    if (!RST_N) begin
      state         <= S_IDLE;
      current_slot  <= 0;
      invalidate_ptr<= 0;
      // Initialize all per-slot registers and (optionally) clear memory.
      for (i = 0; i < NUM_SLOTS; i = i + 1) begin
        valid[i]         <= 1'b0;
        bytes_rcvd[i]    <= 16'd0;
        bytes_sent[i]    <= 16'd0;
        frame_complete[i] <= 1'b0;
        write_ptr[i]     <= '0;
        read_ptr[i]      <= '0;
        for (j = 0; j < MEM_DEPTH; j = j + 1)
          prt_table[i][j] <= '0;
      end
    end else begin
      state <= next_state;
      case (state)
        // ----- Write Transaction -----
        S_WRITE_START: begin
          // Transition triggered by EN_start_writing_prt_entry.
          // Choose a free slot and initialize write pointers and counters.
          current_slot              <= free_slot;
          write_ptr[free_slot]      <= '0;
          bytes_rcvd[free_slot]     <= 16'd0;
          bytes_sent[free_slot]     <= 16'd0;
          frame_complete[free_slot] <= 1'b0;
        end

        S_WRITE: begin
          // Data transfer: when EN_write_prt_entry is high, write one data byte.
          if (EN_write_prt_entry) begin
            prt_table[current_slot][ write_ptr[current_slot] ] <= write_prt_entry_data;
            write_ptr[current_slot]                            <= write_ptr[current_slot] + 1;
            bytes_rcvd[current_slot]                           <= bytes_rcvd[current_slot] + 1;
          end
        end

        S_WRITE_FINISH: begin
          // Transition triggered by EN_finish_writing_prt_entry (or if memory full).
          // Finalize write: mark frame as complete and valid.
          frame_complete[current_slot] <= 1'b1;
          valid[current_slot]          <= 1'b1;
        end

        // ----- Read Transaction -----
        S_READ_START: begin
          // Transition triggered by EN_start_reading_prt_entry.
          // Select the requested slot and initialize read pointers.
          current_slot             <= start_reading_prt_entry_slot;
          read_ptr[current_slot]   <= '0;
          bytes_sent[current_slot] <= 16'd0;
        end

        S_READ: begin
          // Data transfer: when EN_read_prt_entry is high, output one byte.
          if (EN_read_prt_entry) begin
            read_ptr[current_slot]   <= read_ptr[current_slot] + 1;
            bytes_sent[current_slot] <= bytes_sent[current_slot] + 1;
          end
        end

        // ----- Invalidate Transaction -----
        S_INVALIDATE_INIT: begin
          // Transition triggered by EN_invalidate_prt_entry.
          // Initialize the invalidation pointer.
          invalidate_ptr <= '0;
        end

        S_INVALIDATE_RUN: begin
          // Sequentially clear the memory for the specified slot.
          prt_table[invalidate_prt_entry_slot][invalidate_ptr] <= '0;
          if (invalidate_ptr == MEM_DEPTH - 1) begin
            // Once done, reset the slot’s registers.
            valid[invalidate_prt_entry_slot]           <= 1'b0;
            bytes_rcvd[invalidate_prt_entry_slot]      <= 16'd0;
            bytes_sent[invalidate_prt_entry_slot]      <= 16'd0;
            frame_complete[invalidate_prt_entry_slot]  <= 1'b0;
          end
          invalidate_ptr <= invalidate_ptr + 1;
        end

        default: ; // No register updates in S_IDLE
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
        // Once acknowledged, transition to data transfer.
        next_state = S_WRITE;
      end

      S_WRITE: begin
        // Remain in S_WRITE until either memory is full or the finish enable is asserted.
        if ((write_ptr[current_slot] == MEM_DEPTH - 1) || EN_finish_writing_prt_entry)
          next_state = S_WRITE_FINISH;
        else
          next_state = S_WRITE;
      end

      S_WRITE_FINISH: begin
        // After finishing, return to idle.
        next_state = S_IDLE;
      end

      S_READ_START: begin
        next_state = S_READ;
      end

      S_READ: begin
        // Remain in S_READ while data transfer continues; exit when done.
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
  // For start–type transactions, a one–cycle ready pulse is issued upon state entry.
  // For data–transfer states (S_WRITE and S_READ), the ready signal is continuously high.
  assign RDY_start_writing_prt_entry  = (state == S_WRITE_START)    && state_entry;
  assign RDY_finish_writing_prt_entry = (state == S_WRITE_FINISH)   && state_entry;
  assign RDY_start_reading_prt_entry  = (state == S_READ_START)     && state_entry;
  assign RDY_invalidate_prt_entry     = (state == S_INVALIDATE_INIT) && state_entry;
  
  // For data transfer states, the ready signal is asserted continuously.
  assign RDY_write_prt_entry = (state == S_WRITE);
  assign RDY_read_prt_entry  = (state == S_READ);

  // The chosen free slot is output when beginning a write transaction.
  assign start_writing_prt_entry = current_slot;

  //====================================================================
  // Read Data Output
  //====================================================================
  // The read data bus is DATA_WIDTH+1 bits wide.
  // The lower DATA_WIDTH bits hold the frame data; the MSB is a "complete" flag.
  // When read_ptr equals the number of bytes received, the complete flag is set.
  assign read_prt_entry = (read_ptr[current_slot] >= bytes_rcvd[current_slot]) ?
                          {1'b1, {DATA_WIDTH{1'b0}}} :
                          {1'b0, prt_table[current_slot][read_ptr[current_slot]]};

endmodule
