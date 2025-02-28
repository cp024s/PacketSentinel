module mkPRT #(
  parameter DATA_WIDTH = 8,       // Change this to support wider data words if needed
  parameter MEM_DEPTH  = 2000,     // Depth of each table
  parameter NUM_SLOTS  = 2         // Number of PRT slots (fixed to 2 in this design)
) (
  input  logic                   CLK,
  input  logic                   RST_N,
  
  // actionvalue method: start_writing_prt_entry
  input  logic                   EN_start_writing_prt_entry,
  output logic                   start_writing_prt_entry, // returns the chosen slot (0 or 1)
  output logic                   RDY_start_writing_prt_entry,

  // action method: write_prt_entry
  input  logic [DATA_WIDTH-1:0]  write_prt_entry_data,
  input  logic                   EN_write_prt_entry,
  output logic                   RDY_write_prt_entry,
  
  // action method: finish_writing_prt_entry
  input  logic                   EN_finish_writing_prt_entry,
  output logic                   RDY_finish_writing_prt_entry,

  // action method: invalidate_prt_entry
  input  logic                   invalidate_prt_entry_slot, // selects slot 0 or 1
  input  logic                   EN_invalidate_prt_entry,
  output logic                   RDY_invalidate_prt_entry,

  // action method: start_reading_prt_entry
  input  logic                   start_reading_prt_entry_slot, // selects slot 0 or 1
  input  logic                   EN_start_reading_prt_entry,
  output logic                   RDY_start_reading_prt_entry,

  // actionvalue method: read_prt_entry
  input  logic                   EN_read_prt_entry,
  output logic [DATA_WIDTH:0]    read_prt_entry, // [DATA_WIDTH-1:0] = data, [DATA_WIDTH] = complete flag
  output logic                   RDY_read_prt_entry,

  // value method: is_prt_slot_free
  output logic                   is_prt_slot_free,
  output logic                   RDY_is_prt_slot_free
);

  //==================================================
  // FSM state definitions
  //==================================================
  typedef enum logic [2:0] {
    S_IDLE,         // Waiting for a command
    S_WRITE_START,  // Begin a write operation: choose a free slot and reset counters
    S_WRITE,        // Actively writing data to the table
    S_WRITE_FINISH, // Finish writing: mark the entry as valid and complete
    S_READ_START,   // Begin a read operation: choose the requested slot and reset read pointer
    S_READ,         // Read data out of the table
    S_INVALIDATE    // Invalidate a given slot
  } state_t;

  state_t state, next_state;
  logic      current_slot; // Holds the slot being used (0 or 1)

  //==================================================
  // Per-slot registers and pointers
  //==================================================
  // Write and read address pointers for each slot
  logic [15:0] wr_addr [NUM_SLOTS-1:0];
  logic [15:0] rd_addr [NUM_SLOTS-1:0];

  // Counters for number of bytes received and sent, as well as status flags
  logic [15:0] prt_bytes_rcvd     [NUM_SLOTS-1:0];
  logic [15:0] prt_bytes_sent_req [NUM_SLOTS-1:0];
  logic [15:0] prt_bytes_sent_res [NUM_SLOTS-1:0];
  logic        prt_is_frame_full  [NUM_SLOTS-1:0];
  logic        prt_valid          [NUM_SLOTS-1:0];

  //==================================================
  // Memory table: two slots, each MEM_DEPTH deep
  //==================================================
  // The table is implemented as a 2D array:
  // prt_table[slot][address]
  logic [DATA_WIDTH-1:0] prt_table [NUM_SLOTS-1:0][0:MEM_DEPTH-1];

  //==================================================
  // FSM: Sequential state and register updates
  //==================================================
  integer i;
  always_ff @(posedge CLK or negedge RST_N) begin
    if (!RST_N) begin
      state <= S_IDLE;
      current_slot <= 0;
      for (i = 0; i < NUM_SLOTS; i = i + 1) begin
        wr_addr[i]           <= 16'd0;
        rd_addr[i]           <= 16'd0;
        prt_bytes_rcvd[i]    <= 16'd0;
        prt_bytes_sent_req[i] <= 16'd0;
        prt_bytes_sent_res[i] <= 16'd0;
        prt_is_frame_full[i]  <= 1'b0;
        prt_valid[i]          <= 1'b0;
      end
    end else begin
      state <= next_state;
      case (state)
        S_WRITE_START: begin
          // Choose a free slot (prefer slot 0 if free)
          if (!prt_valid[0])
            current_slot <= 0;
          else
            current_slot <= 1;
          // Initialize the write pointer and byte counter for the chosen slot
          wr_addr[current_slot]        <= 16'd0;
          prt_bytes_rcvd[current_slot] <= 16'd0;
        end

        S_WRITE: begin
          // If a write entry is enabled, store the data into the table and update pointers/counters
          if (EN_write_prt_entry) begin
            prt_table[current_slot][wr_addr[current_slot]]  <= write_prt_entry_data;
            wr_addr[current_slot]                           <= wr_addr[current_slot] + 16'd1;
            prt_bytes_rcvd[current_slot]                    <= prt_bytes_rcvd[current_slot] + 16'd1;
          end
        end

        S_WRITE_FINISH: begin
          // Mark the frame as complete and the slot as valid; capture the total bytes written
          prt_is_frame_full[current_slot]  <= 1'b1;
          prt_valid[current_slot]          <= 1'b1;
          prt_bytes_sent_res[current_slot] <= prt_bytes_rcvd[current_slot];
        end

        S_READ_START: begin
          // Set the current slot based on the external read slot selection and reset the read pointer
          current_slot                     <= start_reading_prt_entry_slot;
          rd_addr[current_slot]            <= 16'd0;
          prt_bytes_sent_req[current_slot] <= 16'd0;
        end

        S_READ: begin
          if (EN_read_prt_entry) begin
            rd_addr[current_slot]            <= rd_addr[current_slot] + 16'd1;
            prt_bytes_sent_req[current_slot] <= rd_addr[current_slot] + 16'd1;
          end
        end

        S_INVALIDATE: begin
          // Invalidate the requested slot (provided on the invalidate_prt_entry_slot input)
          prt_valid[invalidate_prt_entry_slot]           <= 1'b0;
          prt_is_frame_full[invalidate_prt_entry_slot]   <= 1'b0;
        end

        default: begin
          // No register updates in S_IDLE and any undefined state
        end
      endcase
    end
  end

  //==================================================
  // FSM: Combinational next state logic with explicit conditions
  //==================================================
  always_comb begin
    next_state = state;
    case (state)
      S_IDLE: begin
        // If a start-writing command is enabled and at least one slot is free, begin a write.
        if (EN_start_writing_prt_entry && ((!prt_valid[0]) || (!prt_valid[1])))
          next_state = S_WRITE_START;
        // Else if a start-reading command is enabled and the requested slot is valid, begin a read.
        else if (EN_start_reading_prt_entry && prt_valid[start_reading_prt_entry_slot])
          next_state = S_READ_START;
        // Else if an invalidate command is enabled, go to invalidate state.
        else if (EN_invalidate_prt_entry)
          next_state = S_INVALIDATE;
        else
          next_state = S_IDLE;
      end

      S_WRITE_START: begin
        // After initializing, immediately transition to the write state.
        next_state = S_WRITE;
      end

      S_WRITE: begin
        // Remain in write state while write operations continue.
        // Transition to finish state when finish command is enabled.
        if (EN_finish_writing_prt_entry)
          next_state = S_WRITE_FINISH;
        else
          next_state = S_WRITE;
      end

      S_WRITE_FINISH: begin
        // After finishing, return to idle.
        next_state = S_IDLE;
      end

      S_READ_START: begin
        // After initializing read pointers, transition to read state.
        next_state = S_READ;
      end

      S_READ: begin
        // In this simple example, we stay in read state while EN_read_prt_entry is active.
        // When no read enable is asserted, return to idle.
        if (!EN_read_prt_entry)
          next_state = S_IDLE;
        else
          next_state = S_READ;
      end

      S_INVALIDATE: begin
        // After invalidation, return to idle.
        next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  //==================================================
  // Output assignments for ready signals and action values
  //==================================================
  assign RDY_start_writing_prt_entry = (state == S_IDLE) && ((!prt_valid[0]) || (!prt_valid[1]));
  assign RDY_write_prt_entry         = (state == S_WRITE);
  assign RDY_finish_writing_prt_entry  = (state == S_WRITE);
  assign RDY_invalidate_prt_entry    = (state == S_IDLE);
  assign RDY_start_reading_prt_entry = (state == S_IDLE) && prt_valid[start_reading_prt_entry_slot];
  assign RDY_read_prt_entry          = (state == S_READ);
  assign RDY_is_prt_slot_free        = 1'b1;

  // The start_writing_prt_entry output returns the chosen slot.
  assign start_writing_prt_entry = current_slot;

  // A slot is free if at least one of the slots is not valid.
  assign is_prt_slot_free = (!prt_valid[0] || !prt_valid[1]);

  // The read_prt_entry output concatenates the data from the table
  // and a “complete” flag indicating the end of the frame.
  // When the read pointer equals the number of bytes received, the frame is complete.
  assign read_prt_entry = { 
    prt_table[current_slot][rd_addr[current_slot]], 
    (rd_addr[current_slot] == prt_bytes_rcvd[current_slot])
  };

endmodule
