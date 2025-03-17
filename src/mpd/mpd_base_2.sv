// Master packet dealer Version 2

`timescale 1ns/1ps

//================================================================
// Top–Level Module: mkMPD
// This module implements a Master Packet Dealer that:
//  • Uses an AXI master interface to perform write (store incoming packet)
//    and read (transmit packet) transactions.
//  • Instantiates the provided Packet Reference Table (PRT_v2) for packet storage.
//  • Extracts a header (first HDR_LEN bytes) and sends it via a handshake
//    (EN_get_header/ RDY_get_header) to a firewall engine.
//  • Uses additional handshake signals (EN_send_header, RDY_send_header,
//    enable_firewall_en, EN_enable_firewall, RDY_enable_firewall) to receive
//    the firewall decision.
//  • Based on the firewall result (send_header_result), either starts an AXI
//    read transaction for transmission or invalidates the stored packet.
//================================================================

module mkMPD(
  input  logic CLK,
  input  logic RST_N,

  //-------------------- AXI Write Address Channel --------------------
  output logic         eth0_master_awvalid,
  output logic [31:0]  eth0_master_awaddr,
  output logic [2:0]   eth0_master_awprot,
  output logic [2:0]   eth0_master_awsize,
  input  logic         eth0_master_m_awready_awready,

  //-------------------- AXI Write Data Channel -----------------------
  output logic         eth0_master_wvalid,
  output logic [31:0]  eth0_master_wdata,
  output logic [3:0]   eth0_master_wstrb,
  input  logic         eth0_master_m_wready_wready,

  //-------------------- AXI Write Response Channel -------------------
  input  logic         eth0_master_m_bvalid_bvalid,
  input  logic [1:0]   eth0_master_m_bvalid_bresp,
  output logic         eth0_master_bready,

  //-------------------- AXI Read Address Channel ---------------------
  output logic         eth0_master_arvalid,
  output logic [31:0]  eth0_master_araddr,
  output logic [2:0]   eth0_master_arprot,
  output logic [2:0]   eth0_master_arsize,
  input  logic         eth0_master_m_arready_arready,

  //-------------------- AXI Read Data Channel ------------------------
  input  logic         eth0_master_m_rvalid_rvalid,
  input  logic [1:0]   eth0_master_m_rvalid_rresp,
  input  logic [31:0]  eth0_master_m_rvalid_rdata,
  output logic         eth0_master_rready,

  //-------------------- Header Extraction Interface ------------------
  input  logic         EN_get_header,   // External trigger to extract header
  output logic [159:0] get_header,      // 20 bytes x 8 = 160 bits header output
  output logic         RDY_get_header,  // Indicates header is available

  //-------------------- Send Header (Firewall) Interface -------------
  // (Assumed: these signals interface with the firewall engine.)
  input  logic [47:0]  send_header_ethid_in, // Ethernet ID input from firewall path
  input  logic [1:0]   send_header_tag_in,   // Slot tag input (from PRT)
  output logic         send_header_result,   // Firewall decision result: safe (1) or unsafe (0)
  output logic         EN_send_header,       // Initiate sending header to firewall
  input  logic         RDY_send_header,      // Firewall handshake ready

  //-------------------- Firewall Enable Interface ---------------------
  output logic         enable_firewall_en,   // Signal to enable firewall checking
  input  logic         EN_enable_firewall,   // Handshake: firewall engine enable input
  output logic         RDY_enable_firewall   // Handshake: MPD ready for firewall enable
);

  //==================================================================
  // Parameters and Local Declarations
  //==================================================================
  parameter DATA_WIDTH = 8;      // PRT data width (1 byte)
  parameter MEM_DEPTH  = 1518;   // Maximum words per packet
  parameter NUM_SLOTS  = 10;     // Number of packet storage slots
  parameter HDR_LEN    = 20;     // Header length (bytes)
  
  // Internal FSM states
  typedef enum logic [3:0] {
    S_IDLE,
    S_ALLOC_SLOT,        // Allocate a free slot via PRT
    S_AXI_WRITE_SETUP,   // Setup AXI write transaction for packet data
    S_WRITE_PKT,         // Write packet data to PRT while capturing header
    S_WRITE_FINISH,      // Finish writing packet into PRT
    S_EXTRACT_HEADER,    // Output captured header via get_header
    S_SEND_HEADER,       // Initiate header send handshake to firewall
    S_WAIT_FIREWALL,     // Wait for firewall decision (via send_header_result)
    S_DECIDE,            // Decide based on firewall: transmit or invalidate
    S_AXI_READ_SETUP,    // Setup AXI read transaction for safe packet
    S_READ_PKT,          // Read packet data from PRT for transmission
    S_TRANSMIT_FINISH,   // Finish AXI read transaction and transmission
    S_INVALIDATE,        // Invalidate PRT entry if unsafe
    S_DONE               // Complete transaction and return to idle
  } state_t;
  
  state_t state, next_state;
  
  // Counters and buffers for packet data and header extraction
  logic [$clog2(MEM_DEPTH)-1:0] pkt_byte_count;
  logic [$clog2(HDR_LEN+1)-1:0] header_count;
  logic [HDR_LEN*8-1:0]         header_buffer;  // accumulates first HDR_LEN bytes
  
  // A simple flag to indicate firewall decision (assumed to be provided externally)
  // (For this example, we treat send_header_result as a registered input.)
  logic firewall_safe;
  
  //==================================================================
  // AXI Master Control Signals (Simple assignments for illustration)
  // In a full design these would be replaced with full AXI protocol FSMs.
  //==================================================================
  // For this example, when not performing an AXI transaction, drive the signals low.
  always_comb begin
    eth0_master_awvalid = 1'b0;
    eth0_master_awaddr  = 32'd0;
    eth0_master_awprot  = 3'd0;
    eth0_master_awsize  = 3'd0;
    
    eth0_master_wvalid  = 1'b0;
    eth0_master_wdata   = 32'd0;
    eth0_master_wstrb   = 4'd0;
    
    eth0_master_bready  = 1'b0;
    
    eth0_master_arvalid = 1'b0;
    eth0_master_araddr  = 32'd0;
    eth0_master_arprot  = 3'd0;
    eth0_master_arsize  = 3'd0;
    
    eth0_master_rready  = 1'b0;
  end

  // For our example, we assume AXI transactions to/from external memory are
  // performed “behind the scenes” once our FSM initiates a write or read.
  // (The AXI channels here are placeholders.)

  //==================================================================
  // Instantiate the Packet Reference Table (PRT_v2)
  //==================================================================
  // Internal signals for interfacing with PRT_v2:
  logic                         PRT_EN_start_writing;
  logic                         PRT_RDY_start_writing;
  logic [$clog2(NUM_SLOTS)-1:0]  PRT_start_slot;
  
  logic                         PRT_EN_write;
  logic                         PRT_RDY_write;
  logic [DATA_WIDTH-1:0]        PRT_write_data;
  
  logic                         PRT_EN_finish_writing;
  logic                         PRT_RDY_finish_writing;
  
  logic                         PRT_EN_start_read;
  logic                         PRT_RDY_start_read;
  logic [$clog2(NUM_SLOTS)-1:0]  PRT_start_read_slot;
  
  logic                         PRT_EN_read;
  logic                         PRT_RDY_read;
  logic [DATA_WIDTH:0]          PRT_read_data;
  
  logic                         PRt_EN_invalidate;
  logic                         PRt_RDY_invalidate;
  logic [$clog2(NUM_SLOTS)-1:0]  PRt_invalidate_slot;
  
  logic                         PRt_is_slot_free;
  logic                         PRt_RDY_is_slot_free;
  
  PRT_v2 #(
    .DATA_WIDTH(DATA_WIDTH),
    .MEM_DEPTH(MEM_DEPTH),
    .NUM_SLOTS(NUM_SLOTS)
  ) prt_inst (
    .CLK                          (CLK),
    .RST_N                        (RST_N),
    // Write transaction interface
    .EN_start_writing_prt_entry   (PRT_EN_start_writing),
    .RDY_start_writing_prt_entry  (PRT_RDY_start_writing),
    .start_writing_prt_entry      (PRT_start_slot),
    .EN_write_prt_entry           (PRT_EN_write),
    .RDY_write_prt_entry          (PRT_RDY_write),
    .write_prt_entry_data         (PRT_write_data),
    .EN_finish_writing_prt_entry  (PRT_EN_finish_writing),
    .RDY_finish_writing_prt_entry (PRT_RDY_finish_writing),
    // Invalidate transaction interface
    .EN_invalidate_prt_entry      (PRt_EN_invalidate),
    .RDY_invalidate_prt_entry     (PRt_RDY_invalidate),
    .invalidate_prt_entry_slot    (PRt_invalidate_slot),
    // Read transaction interface
    .EN_start_reading_prt_entry   (PRT_EN_start_read),
    .RDY_start_reading_prt_entry  (PRT_RDY_start_read),
    .start_reading_prt_entry_slot (PRT_start_read_slot),
    .EN_read_prt_entry            (PRT_EN_read),
    .RDY_read_prt_entry           (PRT_RDY_read),
    .read_prt_entry               (PRT_read_data),
    // Free slot check
    .is_prt_slot_free             (PRt_is_slot_free),
    .RDY_is_prt_slot_free         (PRt_RDY_is_slot_free)
  );
  
  //==================================================================
  // Internal FSM: Control of Packet Reception, Header Extraction,
  // Firewall Interface, and Packet Transmission/Invalidation.
  //==================================================================
  
  typedef enum logic [3:0] {
    S_IDLE,
    S_ALLOC_SLOT,
    S_AXI_WRITE_SETUP,
    S_WRITE_PKT,
    S_WRITE_FINISH,
    S_EXTRACT_HEADER,
    S_SEND_HEADER,
    S_WAIT_FIREWALL,
    S_DECIDE,
    S_AXI_READ_SETUP,
    S_READ_PKT,
    S_TRANSMIT_FINISH,
    S_INVALIDATE,
    S_DONE
  } fsm_state_t;
  
  fsm_state_t fsm_state, fsm_next;
  
  // Simple registers for AXI simulation (packet data generation example)
  // For this example we generate packet data as an incrementing counter.
  logic [7:0] pkt_data_counter;
  
  //==================================================================
  // FSM: Sequential State Update
  //==================================================================
  always_ff @(posedge CLK or negedge RST_N) begin
    if (!RST_N) begin
      fsm_state         <= S_IDLE;
      pkt_byte_count    <= '0;
      header_count      <= '0;
      header_buffer     <= '0;
      pkt_data_counter  <= 8'd0;
    end else begin
      fsm_state <= fsm_next;
      // In S_WRITE_PKT, update packet byte count and capture header data
      if (fsm_state == S_WRITE_PKT) begin
        if (PRT_RDY_write) begin
          pkt_byte_count <= pkt_byte_count + 1;
          // Capture header bytes until HDR_LEN is reached
          if (header_count < HDR_LEN) begin
            header_buffer <= {header_buffer[HDR_LEN*8-9:0], PRT_write_data};
            header_count  <= header_count + 1;
          end
          // For this example, increment packet data counter
          pkt_data_counter <= pkt_data_counter + 1;
        end
      end
      // Reset counters on transaction completion
      if (fsm_state == S_DONE) begin
        pkt_byte_count <= '0;
        header_count   <= '0;
        header_buffer  <= '0;
        pkt_data_counter <= 8'd0;
      end
    end
  end

  //==================================================================
  // FSM: Combinational Next State Logic and Control Signal Assignments
  //==================================================================
  always_comb begin
    // Default assignments
    fsm_next = fsm_state;
    
    // Default PRT control signals
    PRT_EN_start_writing   = 1'b0;
    PRT_EN_write           = 1'b0;
    PRT_EN_finish_writing  = 1'b0;
    PRT_EN_start_read      = 1'b0;
    PRT_EN_read            = 1'b0;
    PRt_EN_invalidate      = 1'b0;
    
    // Default outputs for header interface and firewall interface
    RDY_get_header         = 1'b0;
    get_header             = '0;
    
    EN_send_header         = 1'b0;
    enable_firewall_en     = 1'b0;
    
    // Default AXI (placeholders) remain deasserted.
    
    // FSM state transitions
    case (fsm_state)
      S_IDLE: begin
        // Wait until an external trigger (EN_get_header) occurs and a free PRT slot is available.
        if (EN_get_header && PRt_is_slot_free)
          fsm_next = S_ALLOC_SLOT;
      end
      
      S_ALLOC_SLOT: begin
        // Initiate start of PRT write transaction.
        PRT_EN_start_writing = 1'b1;
        if (PRT_RDY_start_writing)
          fsm_next = S_AXI_WRITE_SETUP;
      end
      
      S_AXI_WRITE_SETUP: begin
        // In this state, we assume an AXI write transaction is initiated to store packet data.
        // (In a full design, the AXI channels would be driven here.)
        fsm_next = S_WRITE_PKT;
      end
      
      S_WRITE_PKT: begin
        // Enable writing into PRT.
        PRT_EN_write = 1'b1;
        // Drive write data from an internal counter (simulating incoming packet bytes).
        // (Connect PRT_write_data below.)
        // Continue writing until a predetermined packet length is reached.
        if (pkt_byte_count == MEM_DEPTH - 1) begin
          fsm_next = S_WRITE_FINISH;
        end
        // Alternatively, an external finish signal could be used.
      end
      
      S_WRITE_FINISH: begin
        PRT_EN_finish_writing = 1'b1;
        if (PRT_RDY_finish_writing)
          fsm_next = S_EXTRACT_HEADER;
      end
      
      S_EXTRACT_HEADER: begin
        // Output the captured header.
        get_header    = header_buffer;
        RDY_get_header = 1'b1;
        fsm_next      = S_SEND_HEADER;
      end
      
      S_SEND_HEADER: begin
        // Initiate sending header to firewall.
        EN_send_header = 1'b1;
        if (RDY_send_header) // handshake from firewall engine
          fsm_next = S_WAIT_FIREWALL;
      end
      
      S_WAIT_FIREWALL: begin
        // Wait here until the firewall decision is available.
        // For this example, we assume send_header_result is updated externally.
        // Latch the decision.
        firewall_safe = send_header_result;
        fsm_next = S_DECIDE;
      end
      
      S_DECIDE: begin
        if (firewall_safe)
          // If safe, proceed to initiate transmission (AXI read from PRT)
          fsm_next = S_AXI_READ_SETUP;
        else
          // If unsafe, invalidate the PRT entry.
          fsm_next = S_INVALIDATE;
      end
      
      S_AXI_READ_SETUP: begin
        // Initiate read transaction from PRT for transmission.
        PRT_EN_start_read = 1'b1;
        if (PRT_RDY_start_read)
          fsm_next = S_READ_PKT;
      end
      
      S_READ_PKT: begin
        // Enable reading packet data from PRT.
        PRT_EN_read = 1'b1;
        // For this example, assume we read until the entire packet is sent.
        if (PRT_RDY_read && (PRT_read_data[DATA_WIDTH] == 1'b1)) // MSB high indicates end of packet
          fsm_next = S_TRANSMIT_FINISH;
      end
      
      S_TRANSMIT_FINISH: begin
        // In a complete design, here the packet would be sent out via the AXI read channel.
        // After transmission, complete the transaction.
        fsm_next = S_DONE;
      end
      
      S_INVALIDATE: begin
        // Invalidate the PRT entry.
        PRt_EN_invalidate = 1'b1;
        fsm_next = S_DONE;
      end
      
      S_DONE: begin
        // Transaction complete. Return to idle.
        fsm_next = S_IDLE;
      end
      
      default: fsm_next = S_IDLE;
    endcase
  end

  //==================================================================
  // Drive PRT Write Data: Use the internal packet data counter as source.
  //==================================================================
  assign PRT_write_data = pkt_data_counter;
  
  //==================================================================
  // AXI Master (Write/Read) channels would normally be driven here.
  // For this example, they are left as placeholders.
  //==================================================================

  //==================================================================
  // Firewall enable handshake
  // For this example, we simply assert RDY_enable_firewall when in DECIDE state.
  //==================================================================
  assign RDY_enable_firewall = (fsm_state == S_DECIDE) ? 1'b1 : 1'b0;
  
  //==================================================================
  // (Optional) Additional logic to drive the AXI interface based on FSM state
  // could be added here.
  //==================================================================

endmodule

//================================================================
// The PRT_v2 module is assumed to be as provided below.
// (The code below is identical to your given version.)
//================================================================
module PRT_v2 #(
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
        next_state = S_WRITE;
      end

      S_WRITE: begin
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

  // Ready Signal Generation
  assign RDY_start_writing_prt_entry  = (state == S_WRITE_START)    && state_entry;
  assign RDY_finish_writing_prt_entry = (state == S_WRITE_FINISH)   && state_entry;
  assign RDY_start_reading_prt_entry  = (state == S_READ_START)     && state_entry;
  assign RDY_invalidate_prt_entry     = (state == S_INVALIDATE_INIT) && state_entry;
  
  assign RDY_write_prt_entry = (state == S_WRITE);
  assign RDY_read_prt_entry  = (state == S_READ);
  
  assign start_writing_prt_entry = current_slot;
  
  assign read_prt_entry = (read_ptr[current_slot] >= bytes_rcvd[current_slot]) ?
                          {1'b1, {DATA_WIDTH{1'b0}}} :
                          {1'b0, prt_table[current_slot][read_ptr[current_slot]]};

endmodule
