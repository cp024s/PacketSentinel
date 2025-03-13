`timescale 1ns/1ps

//====================================================================
// Dual-Port BRAM Module
// This module instantiates a dual–port BRAM with one write port and one read port.
// The memory is implemented as a register array that synthesis tools will infer as BRAM.
//====================================================================
module dual_port_bram #(
  parameter DATA_WIDTH = 8,
  parameter ADDR_WIDTH = 12  // For NUM_SLOTS=2 and MEM_DEPTH=1518, ADDR_WIDTH = SLOT_WIDTH + BYTE_ADDR_WIDTH
)(
  input  logic                    CLK,
  // Write port
  input  logic                    wr_en,
  input  logic [ADDR_WIDTH-1:0]   wr_addr,
  input  logic [DATA_WIDTH-1:0]   wr_data,
  // Read port
  input  logic                    rd_en,
  input  logic [ADDR_WIDTH-1:0]   rd_addr,
  output logic [DATA_WIDTH-1:0]   rd_data
);

  // Inferred dual-port BRAM memory array.
  reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

  // Write operation (synchronous)
  always_ff @(posedge CLK) begin
    if (wr_en)
      mem[wr_addr] <= wr_data;
  end

  // Read operation (synchronous)
  always_ff @(posedge CLK) begin
    if (rd_en)
      rd_data <= mem[rd_addr];
  end

endmodule

//====================================================================
// Packet Reference Table (PRT) Module with Dual-Port BRAM
//====================================================================
module PRT_v2 #(
  parameter DATA_WIDTH = 8,             // Data bus width (1 byte)
  parameter MEM_DEPTH  = 1518,           // Maximum frame size in bytes
  parameter NUM_SLOTS  = 2,              // Number of PRT slots
  // Calculate address widths:
  parameter SLOT_WIDTH = $clog2(NUM_SLOTS),
  parameter BYTE_ADDR_WIDTH = $clog2(MEM_DEPTH),
  parameter ADDR_WIDTH = SLOT_WIDTH + BYTE_ADDR_WIDTH  // Total BRAM address width
) (
  input  logic                          CLK,
  input  logic                          RST_N,
  
  // -------- Write Transaction Handshake --------
  input  logic                          EN_start_writing_prt_entry,
  output logic [SLOT_WIDTH-1:0]         start_writing_prt_entry,
  output logic                          RDY_start_writing_prt_entry,
  
  input  logic [DATA_WIDTH-1:0]         write_prt_entry_data,
  input  logic                          EN_write_prt_entry,
  output logic                          RDY_write_prt_entry,
  
  input  logic                          EN_finish_writing_prt_entry,
  output logic                          RDY_finish_writing_prt_entry,
  
  // -------- Invalidate Transaction Handshake --------
  input  logic [SLOT_WIDTH-1:0]         invalidate_prt_entry_slot,
  input  logic                          EN_invalidate_prt_entry,
  output logic                          RDY_invalidate_prt_entry,
  
  // -------- Read Transaction Handshake --------
  input  logic [SLOT_WIDTH-1:0]         start_reading_prt_entry_slot,
  input  logic                          EN_start_reading_prt_entry,
  output logic                          RDY_start_reading_prt_entry,
  
  input  logic                          EN_read_prt_entry,
  output logic [DATA_WIDTH:0]           read_prt_entry,  // {complete flag, data}
  output logic                          RDY_read_prt_entry,
  
  // -------- Free Slot Check --------
  output logic                          is_prt_slot_free,
  output logic                          RDY_is_prt_slot_free
);

  //====================================================================
  // FSM State Definitions
  //====================================================================
  typedef enum logic [2:0] {
    S_IDLE,            // Waiting for any transaction enable.
    S_WRITE_START,     // Transition: start write (choose free slot & initialize write pointers).
    S_WRITE,           // Data transfer: writing frame data.
    S_WRITE_FINISH,    // Transition: finish write (mark frame complete and valid).
    S_READ_START,      // Transition: start read (select slot & initialize read pointer).
    S_READ,            // Data transfer: reading frame data.
    S_INVALIDATE_INIT, // Transition: start invalidate (initialize pointer for clearing).
    S_INVALIDATE_RUN   // Invalidate: sequentially clear the slot.
  } state_t;

  state_t state, next_state;
  
  // Generate a one–cycle pulse upon state transition.
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
  // Metadata Registers for Each Slot (Frame Structure)
  //====================================================================
  // For each slot, maintain:
  //   valid         : 1 if the slot holds a valid frame.
  //   bytes_rcvd    : counter for bytes written.
  //   bytes_sent    : counter for bytes read.
  //   frame_complete: flag set when the entire frame has been received.
  logic                     valid         [NUM_SLOTS-1:0];
  logic [15:0]              bytes_rcvd    [NUM_SLOTS-1:0];
  logic [15:0]              bytes_sent    [NUM_SLOTS-1:0];
  logic                     frame_complete [NUM_SLOTS-1:0];

  // Write and read pointers (within a slot).
  logic [BYTE_ADDR_WIDTH-1:0] write_ptr [NUM_SLOTS-1:0];
  logic [BYTE_ADDR_WIDTH-1:0] read_ptr  [NUM_SLOTS-1:0];

  // Pointer for invalidation.
  logic [BYTE_ADDR_WIDTH-1:0] invalidate_ptr;

  // Current slot being accessed.
  logic [SLOT_WIDTH-1:0] current_slot;

  //====================================================================
  // Free Slot Selection
  // For NUM_SLOTS==2, choose the lowest numbered slot that is not valid.
  //====================================================================
  logic [SLOT_WIDTH-1:0] free_slot;
  always_comb begin
    if (!valid[0])
      free_slot = 0;
    else if (!valid[1])
      free_slot = 1;
    else
      free_slot = 0; // Default (should not occur if a free slot exists)
  end

  assign is_prt_slot_free    = (!valid[0] || !valid[1]);
  assign RDY_is_prt_slot_free = 1'b1;

  //====================================================================
  // BRAM Interface Signals
  //====================================================================
  // Form the BRAM address by concatenating the slot index with the byte address.
  logic [ADDR_WIDTH-1:0] wr_addr, rd_addr;
  assign wr_addr = { current_slot, write_ptr[current_slot] };
  assign rd_addr = { current_slot, read_ptr[current_slot] };

  // Signals to control the dual–port BRAM.
  logic bram_wr_en, bram_rd_en;
  logic [DATA_WIDTH-1:0] bram_rd_data;

  //====================================================================
  // Instantiate Dual-Port BRAM
  //====================================================================
  dual_port_bram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) prt_bram (
    .CLK(CLK),
    .wr_en(bram_wr_en),
    .wr_addr(wr_addr),
    .wr_data(write_prt_entry_data),
    .rd_en(bram_rd_en),
    .rd_addr(rd_addr),
    .rd_data(bram_rd_data)
  );

  //====================================================================
  // FSM: Sequential State and Metadata Updates
  //====================================================================
  integer i;
  always_ff @(posedge CLK or negedge RST_N) begin
    if (!RST_N) begin
      state         <= S_IDLE;
      current_slot  <= 0;
      invalidate_ptr<= '0;  // Reset invalidate pointer
      // Initialize all metadata registers and pointers.
      for (i = 0; i < NUM_SLOTS; i = i + 1) begin
        valid[i]          <= 1'b0;
        bytes_rcvd[i]     <= 16'd0;
        bytes_sent[i]     <= 16'd0;
        frame_complete[i] <= 1'b0;
        write_ptr[i]      <= '0;
        read_ptr[i]       <= '0;
      end
    end else begin
      state <= next_state;
      case (state)
        // ----- Write Transaction -----
        S_WRITE_START: begin
          // On entering S_WRITE_START, select a free slot and initialize its pointers.
          current_slot            <= free_slot;
          write_ptr[free_slot]    <= '0;
          bytes_rcvd[free_slot]   <= 16'd0;
          bytes_sent[free_slot]   <= 16'd0;
          frame_complete[free_slot] <= 1'b0;
        end
        S_WRITE: begin
          if (EN_write_prt_entry) begin
            // Data transfer: each asserted enable writes a byte.
            bytes_rcvd[current_slot] <= bytes_rcvd[current_slot] + 1;
            write_ptr[current_slot]  <= write_ptr[current_slot] + 1;
          end
        end
        S_WRITE_FINISH: begin
          // Mark the frame as complete and valid.
          frame_complete[current_slot] <= 1'b1;
          valid[current_slot]          <= 1'b1;
        end

        // ----- Read Transaction -----
        S_READ_START: begin
          // On entering S_READ_START, select the requested slot and initialize read pointer.
          current_slot           <= start_reading_prt_entry_slot;
          read_ptr[current_slot] <= '0;
          bytes_sent[current_slot] <= 16'd0;
        end
        S_READ: begin
          if (EN_read_prt_entry) begin
            // Data transfer: update read pointer and counter.
            bytes_sent[current_slot] <= bytes_sent[current_slot] + 1;
            read_ptr[current_slot]   <= read_ptr[current_slot] + 1;
          end
        end

        // ----- Invalidate Transaction -----
        S_INVALIDATE_INIT: begin
          // On entering invalidate, initialize the invalidation pointer.
          invalidate_ptr <= '0;
        end
        S_INVALIDATE_RUN: begin
          // Update metadata for the invalidated slot when clearing is complete.
          if (invalidate_ptr == MEM_DEPTH - 1) begin
            valid[invalidate_prt_entry_slot]        <= 1'b0;
            bytes_rcvd[invalidate_prt_entry_slot]     <= 16'd0;
            bytes_sent[invalidate_prt_entry_slot]     <= 16'd0;
            frame_complete[invalidate_prt_entry_slot] <= 1'b0;
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
        // Stay in write state while writing. Transition to finish if finish enable asserted or memory full.
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
        // Remain in read state while data transfer continues; exit when EN_read_prt_entry deasserted or all bytes read.
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
  // BRAM Control: Write and Read Enable Signals
  //====================================================================
  // In S_WRITE, if EN_write_prt_entry is asserted, enable BRAM write.
  assign bram_wr_en = (state == S_WRITE) && EN_write_prt_entry;
  // In S_READ, if EN_read_prt_entry is asserted, enable BRAM read.
  assign bram_rd_en = (state == S_READ) && EN_read_prt_entry;

  //====================================================================
  // Ready Signal Generation
  // For start-type transactions, a one-cycle ready pulse is issued upon entering the state.
  // For data-transfer states, the ready signal is continuously asserted.
  //====================================================================
  assign RDY_start_writing_prt_entry  = (state == S_WRITE_START)    && state_entry;
  assign RDY_finish_writing_prt_entry = (state == S_WRITE_FINISH)   && state_entry;
  assign RDY_start_reading_prt_entry  = (state == S_READ_START)     && state_entry;
  assign RDY_invalidate_prt_entry     = (state == S_INVALIDATE_INIT) && state_entry;
  assign RDY_write_prt_entry          = (state == S_WRITE);
  assign RDY_read_prt_entry           = (state == S_READ);

  // Output the chosen free slot when beginning a write transaction.
  assign start_writing_prt_entry = current_slot;

  //====================================================================
  // Read Data Output
  // The read data bus is DATA_WIDTH+1 bits wide.
  // The lower DATA_WIDTH bits hold the data read from BRAM.
  // The MSB is the "complete" flag (set to 1 when read_ptr >= bytes_rcvd).
  //====================================================================
  assign read_prt_entry = (read_ptr[current_slot] >= bytes_rcvd[current_slot]) ?
                          {1'b1, {DATA_WIDTH{1'b0}}} :
                          {1'b0, bram_rd_data};

endmodule
