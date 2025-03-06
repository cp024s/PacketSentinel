`timescale 1ns/1ps

module PRT #(
  parameter DATA_WIDTH = 8,            // Data bus width (1 byte)
  parameter MEM_DEPTH  = 1518,          // Maximum frame size (in bytes)
  parameter NUM_SLOTS  = 2             // Number of PRT slots
) (
  input  logic                          CLK,
  input  logic                          RST_N,
  
  // ---------- Write Transaction ----------
  // Enable to transition into the "write-start" state.
  input  logic                          EN_start_writing_prt_entry,
  // Once in the write-start state, the PRT outputs the chosen free slot.
  output logic [$clog2(NUM_SLOTS)-1:0]  start_writing_prt_entry,
  // Ready signal that acknowledges the transition into the write-start state.
  output logic                          RDY_start_writing_prt_entry,
  
  // Data transfer during the write transaction.
  // While EN_write_prt_entry is asserted, one byte (from write_prt_entry_data) is written per clock.
  input  logic [DATA_WIDTH-1:0]         write_prt_entry_data,
  input  logic                          EN_write_prt_entry,
  // Ready signal indicates that the PRT is in the write state and is accepting data.
  output logic                          RDY_write_prt_entry,
  
  // Enable signal to finish the write transaction.
  input  logic                          EN_finish_writing_prt_entry,
  // Ready signal indicates that the write transaction has been finalized.
  output logic                          RDY_finish_writing_prt_entry,
  
  // ---------- Invalidate Transaction ----------
  // Specifies which slot to invalidate.
  input  logic [$clog2(NUM_SLOTS)-1:0]  invalidate_prt_entry_slot,
  // Enable signal to start invalidation.
  input  logic                          EN_invalidate_prt_entry,
  // Ready signal indicates that the PRT is in the idle state and can accept an invalidation request.
  output logic                          RDY_invalidate_prt_entry,
  
  // ---------- Read Transaction ----------
  // Specifies which slot to read from.
  input  logic [$clog2(NUM_SLOTS)-1:0]  start_reading_prt_entry_slot,
  // Enable signal to transition into the read-start state.
  input  logic                          EN_start_reading_prt_entry,
  // Ready signal acknowledges that the PRT has transitioned to the read-start state.
  output logic                          RDY_start_reading_prt_entry,
  
  // During a read transaction, while EN_read_prt_entry is asserted the module outputs one byte.
  // The MSB of read_prt_entry indicates a "complete" flag (set when all data has been read).
  input  logic                          EN_read_prt_entry,
  output logic [DATA_WIDTH:0]           read_prt_entry,
  // Ready signal indicates that the PRT is in the read state.
  output logic                          RDY_read_prt_entry,
  
  // ---------- Free Slot Check ----------
  // Indicates if at least one PRT slot is free.
  output logic                          is_prt_slot_free,
  // Always ready to provide the free slot status.
  output logic                          RDY_is_prt_slot_free
);

  //====================================================================
  // FSM State Definitions
  //====================================================================
  typedef enum logic [2:0] {
    S_IDLE,            // Waiting for any enable input
    S_WRITE_START,     // Begin write: choose free slot & initialize write pointers
    S_WRITE,           // Write data: data transfer into the chosen slot
    S_WRITE_FINISH,    // Finish write: mark frame complete and valid
    S_READ_START,      // Begin read: select slot & initialize read pointers
    S_READ,            // Read data: transfer out one byte at a time
    S_INVALIDATE_INIT, // Begin invalidation: initialize pointer to clear slot memory
    S_INVALIDATE_RUN   // Invalidate: sequentially clear the specified slot
  } state_t;

  state_t state, next_state;

  //====================================================================
  // Per–Slot Registers and Memory
  //====================================================================
  // For each slot, the following registers are maintained:
  //   valid         : 1 if the slot holds a valid frame.
  //   bytes_rcvd    : counts bytes received (written) into the frame.
  //   bytes_sent    : counts bytes transferred out (read) from the frame.
  //   frame_complete: indicates that the entire frame has been received.
  logic                     valid        [NUM_SLOTS-1:0];
  logic [15:0]            bytes_rcvd   [NUM_SLOTS-1:0];
  logic [15:0]            bytes_sent   [NUM_SLOTS-1:0];
  logic                     frame_complete [NUM_SLOTS-1:0];

  // Write and read pointers for addressing the frame memory.
  logic [$clog2(MEM_DEPTH)-1:0] write_ptr [NUM_SLOTS-1:0];
  logic [$clog2(MEM_DEPTH)-1:0] read_ptr  [NUM_SLOTS-1:0];

  // The frame data is stored in a 2D memory array.
  logic [DATA_WIDTH-1:0] prt_table [NUM_SLOTS-1:0][0:MEM_DEPTH-1];

  // For invalidation: pointer to clear the memory sequentially.
  logic [$clog2(MEM_DEPTH)-1:0] invalidate_ptr;

  // current_slot holds the slot number being accessed (for either write or read).
  logic [$clog2(NUM_SLOTS)-1:0] current_slot;

  //====================================================================
  // Free Slot Selection (Combinational)
  //====================================================================
  // For this design (NUM_SLOTS==2) choose the lowest numbered slot that is not valid.
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
  assign is_prt_slot_free = (!valid[0] || !valid[1]);
  assign RDY_is_prt_slot_free = 1'b1; // Always ready to check slot status

  //====================================================================
  // FSM: Sequential State and Register Updates
  //====================================================================
  integer i, j;
  always_ff @(posedge CLK or negedge RST_N) begin
    if (!RST_N) begin
      state         <= S_IDLE;
      current_slot  <= 0;
      invalidate_ptr<= 0;
      // Initialize registers and (optionally) clear memory for each slot.
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
          // (Enable provided: EN_start_writing_prt_entry)
          // Choose a free slot and initialize write pointers and counters.
          current_slot               <= free_slot;
          write_ptr[free_slot]       <= '0;
          bytes_rcvd[free_slot]      <= 16'd0;
          bytes_sent[free_slot]      <= 16'd0;
          frame_complete[free_slot]  <= 1'b0;
        end

        S_WRITE: begin
          // (Enable provided: EN_write_prt_entry)
          // Data transfer: Write one byte per clock when EN_write_prt_entry is high.
          if (EN_write_prt_entry) begin
            prt_table[current_slot][ write_ptr[current_slot] ] <= write_prt_entry_data;
            write_ptr[current_slot]  <= write_ptr[current_slot] + 1;
            bytes_rcvd[current_slot] <= bytes_rcvd[current_slot] + 1;
          end
        end

        S_WRITE_FINISH: begin
          // (Enable provided: EN_finish_writing_prt_entry)
          // Finalize the write transaction: mark the frame as complete and valid.
          frame_complete[current_slot] <= 1'b1;
          valid[current_slot]          <= 1'b1;
        end

        // ----- Read Transaction -----
        S_READ_START: begin
          // (Enable provided: EN_start_reading_prt_entry)
          // Initialize read pointers for the requested slot.
          current_slot                 <= start_reading_prt_entry_slot;
          read_ptr[current_slot]       <= '0;
          bytes_sent[current_slot]     <= 16'd0;
        end

        S_READ: begin
          // (Enable provided: EN_read_prt_entry)
          // Data transfer: Read one byte per clock while EN_read_prt_entry is high.
          if (EN_read_prt_entry) begin
            read_ptr[current_slot]   <= read_ptr[current_slot] + 1;
            bytes_sent[current_slot] <= bytes_sent[current_slot] + 1;
          end
        end

        // ----- Invalidate Transaction -----
        S_INVALIDATE_INIT: begin
          // (Enable provided: EN_invalidate_prt_entry)
          // Initialize the invalidation pointer.
          invalidate_ptr <= '0;
        end

        S_INVALIDATE_RUN: begin
          // Sequentially clear the entire memory for the specified slot.
          prt_table[invalidate_prt_entry_slot][invalidate_ptr] <= '0;
          if (invalidate_ptr == MEM_DEPTH - 1) begin
            // After clearing, reset the slot's registers.
            valid[invalidate_prt_entry_slot]         <= 1'b0;
            bytes_rcvd[invalidate_prt_entry_slot]      <= 16'd0;
            bytes_sent[invalidate_prt_entry_slot]      <= 16'd0;
            frame_complete[invalidate_prt_entry_slot]  <= 1'b0;
          end
          invalidate_ptr <= invalidate_ptr + 1;
        end

        default: ; // No update in S_IDLE
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
        next_state = S_WRITE;
      end

      S_WRITE: begin
        // Finish write if the memory is full or if the finish enable is asserted.
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
        // Finish read when EN_read_prt_entry is deasserted or all received bytes are read.
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
  // Output Assignments: Ready Signals and Data Transfer
  //====================================================================
  assign RDY_start_writing_prt_entry  = (state == S_IDLE) && is_prt_slot_free;
  assign RDY_write_prt_entry          = (state == S_WRITE);
  assign RDY_finish_writing_prt_entry = (state == S_WRITE);
  assign RDY_invalidate_prt_entry     = (state == S_IDLE);
  assign RDY_start_reading_prt_entry  = (state == S_IDLE) && valid[start_reading_prt_entry_slot];
  assign RDY_read_prt_entry           = (state == S_READ);

  // The chosen free slot is output once a write transaction is initiated.
  assign start_writing_prt_entry = current_slot;

  // The read data output is DATA_WIDTH+1 bits wide.
  // The lower DATA_WIDTH bits hold the frame data while the MSB is the "complete" flag.
  // When read_ptr reaches the total number of bytes received, the complete flag is set.
  assign read_prt_entry = (read_ptr[current_slot] >= bytes_rcvd[current_slot]) ?
                          {1'b1, {DATA_WIDTH{1'b0}}} :
                          {1'b0, prt_table[current_slot][read_ptr[current_slot]]};

endmodule
