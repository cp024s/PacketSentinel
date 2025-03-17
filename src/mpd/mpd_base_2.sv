`timescale 1ns/1ps

module master_packet_dealer #(
  parameter DATA_WIDTH       = 8,
  parameter MEM_DEPTH        = 1518,
  parameter NUM_SLOTS        = 2,
  parameter HDR_LEN          = 20,                       // Header length in bytes
  parameter SLOT_WIDTH       = $clog2(NUM_SLOTS),
  parameter BYTE_ADDR_WIDTH  = $clog2(MEM_DEPTH),
  parameter ADDR_WIDTH       = SLOT_WIDTH + BYTE_ADDR_WIDTH
)(
  input  logic                    CLK,
  input  logic                    RST_N,

  // Packet Reception Interface (from custom Ethernet IP)
  input  logic                    pkt_valid,   // Asserted when pkt_data is valid
  input  logic [DATA_WIDTH-1:0]   pkt_data,    // Incoming packet byte
  input  logic                    pkt_last,    // Asserted when last byte of frame received

  // Header Extraction Interface
  input  logic                    EN_get_header,  // External trigger to start processing a packet
  output logic [HDR_LEN*8-1:0]    get_header,     // Captured header (20 bytes)
  output logic                    RDY_get_header, // Pulse to indicate header is ready

  // Firewall Header Handshake Interface
  output logic                    EN_send_header, // Initiates header transfer to firewall
  input  logic                    RDY_send_header,// Handshake from firewall interface
  input  logic                    send_header_result, // Firewall decision: 1 = safe, 0 = unsafe
  input  logic [47:0]             send_header_ethid_in, // Ethernet ID from firewall path
  input  logic [SLOT_WIDTH-1:0]   send_header_tag_in,   // PRT slot tag provided by firewall (for verification)

  // Firewall Enable Handshake (optional)
  output logic                    enable_firewall_en,
  input  logic                    EN_enable_firewall,
  output logic                    RDY_enable_firewall,

  // AXI Master Interface (not used in this example; tied to default values)
  output logic                    eth0_master_awvalid,
  output logic [31:0]             eth0_master_awaddr,
  output logic [2:0]              eth0_master_awprot,
  output logic [2:0]              eth0_master_awsize,
  input  logic                    eth0_master_m_awready_awready,
  output logic                    eth0_master_wvalid,
  output logic [31:0]             eth0_master_wdata,
  output logic [3:0]              eth0_master_wstrb,
  input  logic                    eth0_master_m_wready_wready,
  input  logic                    eth0_master_m_bvalid_bvalid,
  input  logic [1:0]              eth0_master_m_bvalid_bresp,
  output logic                    eth0_master_bready,
  output logic                    eth0_master_arvalid,
  output logic [31:0]             eth0_master_araddr,
  output logic [2:0]              eth0_master_arprot,
  output logic [2:0]              eth0_master_arsize,
  input  logic                    eth0_master_m_arready_arready,
  input  logic                    eth0_master_m_rvalid_rvalid,
  input  logic [1:0]              eth0_master_m_rvalid_rresp,
  input  logic [31:0]             eth0_master_m_rvalid_rdata,
  output logic                    eth0_master_rready,

  // Force Stop: Signal to halt reception if packet is unsafe
  output logic                    force_stop_rx
);

  //-------------------------------------------------------------------------
  // Internal FSM State Definition
  //-------------------------------------------------------------------------
  typedef enum logic [3:0] {
    S_IDLE,             // Wait for EN_get_header and free slot
    S_ALLOC_SLOT,       // Allocate a free PRT slot
    S_WRITE_PKT,        // Write packet bytes into PRT & capture header
    S_WRITE_FINISH,     // Finish writing frame (assert finish handshake)
    S_EXTRACT_HEADER,   // Latch header and present on get_header output
    S_SEND_HEADER,      // Initiate handshake to send header to firewall
    S_WAIT_FIREWALL,    // Wait for firewall decision
    S_DECIDE,           // Decide: if safe, read packet; if unsafe, invalidate
    S_READ_PKT,         // Read packet payload from PRT for transmission
    S_TRANSMIT_FINISH,  // Finish read-out / transmission cycle
    S_INVALIDATE,       // Invalidate the PRT slot for unsafe packet
    S_DONE              // Reset counters and return to idle
  } state_t;

  state_t state, next_state;

  //-------------------------------------------------------------------------
  // Internal Registers and Counters
  //-------------------------------------------------------------------------
  // PRT slot allocated (from write allocation handshake)
  logic [SLOT_WIDTH-1:0] current_slot;

  // Counters for header and packet byte count
  logic [$clog2(HDR_LEN+1)-1:0] header_count;
  logic [15:0] packet_byte_count;

  // Header buffer (20 bytes = 160 bits)
  logic [HDR_LEN*8-1:0] header_buffer;

  //-------------------------------------------------------------------------
  // PRT (Packet Reference Table) Handshake Signals
  //-------------------------------------------------------------------------
  // Write transaction signals
  logic EN_start_writing_prt_entry;
  logic [SLOT_WIDTH-1:0] start_writing_prt_entry;
  logic RDY_start_writing_prt_entry;
  logic EN_write_prt_entry;
  logic RDY_write_prt_entry;
  logic EN_finish_writing_prt_entry;
  logic RDY_finish_writing_prt_entry;

  // Invalidate transaction signals
  logic [SLOT_WIDTH-1:0] invalidate_prt_entry_slot;
  logic EN_invalidate_prt_entry;
  logic RDY_invalidate_prt_entry;

  // Read transaction signals
  logic [SLOT_WIDTH-1:0] start_reading_prt_entry_slot;
  logic EN_start_reading_prt_entry;
  logic RDY_start_reading_prt_entry;
  logic EN_read_prt_entry;
  logic [DATA_WIDTH:0] read_prt_entry;
  logic RDY_read_prt_entry;

  // Free slot check
  logic is_prt_slot_free;
  logic RDY_is_prt_slot_free;

  //-------------------------------------------------------------------------
  // Instantiate the PRT_v2 Module
  //-------------------------------------------------------------------------
  PRT_v2 #(
    .DATA_WIDTH(DATA_WIDTH),
    .MEM_DEPTH(MEM_DEPTH),
    .NUM_SLOTS(NUM_SLOTS)
  ) prt_inst (
    .CLK                           (CLK),
    .RST_N                         (RST_N),
    // Write handshake
    .EN_start_writing_prt_entry    (EN_start_writing_prt_entry),
    .start_writing_prt_entry       (start_writing_prt_entry),
    .RDY_start_writing_prt_entry   (RDY_start_writing_prt_entry),
    .write_prt_entry_data          (pkt_data),  // Use incoming byte as write data
    .EN_write_prt_entry            (EN_write_prt_entry),
    .RDY_write_prt_entry           (RDY_write_prt_entry),
    .EN_finish_writing_prt_entry   (EN_finish_writing_prt_entry),
    .RDY_finish_writing_prt_entry  (RDY_finish_writing_prt_entry),
    // Invalidate handshake
    .invalidate_prt_entry_slot     (current_slot), // Invalidate current slot if needed
    .EN_invalidate_prt_entry       (EN_invalidate_prt_entry),
    .RDY_invalidate_prt_entry      (RDY_invalidate_prt_entry),
    // Read handshake
    .start_reading_prt_entry_slot  (current_slot), // Read from the current slot
    .EN_start_reading_prt_entry    (EN_start_reading_prt_entry),
    .RDY_start_reading_prt_entry   (RDY_start_reading_prt_entry),
    .EN_read_prt_entry             (EN_read_prt_entry),
    .read_prt_entry                (read_prt_entry),
    .RDY_read_prt_entry            (RDY_read_prt_entry),
    // Free slot check
    .is_prt_slot_free              (is_prt_slot_free),
    .RDY_is_prt_slot_free          (RDY_is_prt_slot_free)
  );

  //-------------------------------------------------------------------------
  // MPD FSM: Sequential Logic
  //-------------------------------------------------------------------------
  always_ff @(posedge CLK or negedge RST_N) begin
    if (!RST_N) begin
      state              <= S_IDLE;
      header_count       <= '0;
      packet_byte_count  <= '0;
      header_buffer      <= '0;
      current_slot       <= '0;
    end else begin
      state <= next_state;
      case (state)
        S_IDLE: begin
          // Wait for an external trigger and available free slot
          if (EN_get_header && is_prt_slot_free && pkt_valid)
            ; // transition handled in next_state
          else begin
            header_count      <= '0;
            packet_byte_count <= '0;
            header_buffer     <= '0;
          end
        end

        S_ALLOC_SLOT: begin
          // Capture allocated slot from PRT (provided via start_writing_prt_entry)
          current_slot  <= start_writing_prt_entry;
        end

        S_WRITE_PKT: begin
          // When a valid packet byte is received, write it to the PRT
          if (pkt_valid) begin
            // Header capture: shift in the first HDR_LEN bytes
            if (header_count < HDR_LEN) begin
              header_buffer  <= { header_buffer[HDR_LEN*8-9:0], pkt_data };
              header_count   <= header_count + 1;
            end
            // Count total bytes written
            packet_byte_count <= packet_byte_count + 1;
          end
        end

        S_WRITE_FINISH: begin
          // Nothing extra here; the PRT write-finish handshake will mark the frame as valid.
        end

        S_EXTRACT_HEADER: begin
          // Latch header for output
          // (header_buffer holds the first HDR_LEN bytes)
        end

        S_SEND_HEADER: begin
          // Initiate header transfer to firewall (EN_send_header asserted)
        end

        S_WAIT_FIREWALL: begin
          // Wait here for firewall decision (send_header_result)
        end

        S_DECIDE: begin
          // Decision stage: if firewall safe, continue to read out; if unsafe, later assert force_stop.
        end

        S_READ_PKT: begin
          // Reading from PRT is driven by the read handshake. No counter update needed here.
        end

        S_TRANSMIT_FINISH: begin
          // After read is complete, nothing extra here.
        end

        S_INVALIDATE: begin
          // Invalidate the PRT entry for unsafe packet.
        end

        S_DONE: begin
          // Reset counters and prepare for next frame.
          header_count      <= '0;
          packet_byte_count <= '0;
          header_buffer     <= '0;
        end

        default: ;
      endcase
    end
  end

  //-------------------------------------------------------------------------
  // MPD FSM: Combinational Next State Logic and Control Signal Generation
  //-------------------------------------------------------------------------
  always_comb begin
    // Default assignments for control signals
    next_state                = state;
    EN_start_writing_prt_entry= 1'b0;
    EN_write_prt_entry        = 1'b0;
    EN_finish_writing_prt_entry = 1'b0;
    EN_send_header            = 1'b0;
    EN_start_reading_prt_entry= 1'b0;
    EN_read_prt_entry         = 1'b0;
    EN_invalidate_prt_entry   = 1'b0;
    force_stop_rx             = 1'b0;
    // AXI and firewall-enable signals are not used here (set to default)
    enable_firewall_en        = 1'b0;
    RDY_enable_firewall       = 1'b0;
    eth0_master_awvalid       = 1'b0;
    eth0_master_wvalid        = 1'b0;
    eth0_master_arvalid       = 1'b0;
    eth0_master_bready        = 1'b0;
    eth0_master_rready        = 1'b0;

    // Default header output ready pulse is deasserted
    RDY_get_header            = 1'b0;
    get_header                = '0;

    case (state)
      S_IDLE: begin
        if (EN_get_header && is_prt_slot_free && pkt_valid)
          next_state = S_ALLOC_SLOT;
      end

      S_ALLOC_SLOT: begin
        // Assert start write handshake for one cycle
        EN_start_writing_prt_entry = 1'b1;
        next_state = S_WRITE_PKT;
      end

      S_WRITE_PKT: begin
        // While packet data is valid, write to PRT.
        // The PRT write handshake is active as long as pkt_valid is high.
        if (pkt_valid)
          EN_write_prt_entry = 1'b1;
        // When the last byte is received, move to finish write.
        if (pkt_last)
          next_state = S_WRITE_FINISH;
      end

      S_WRITE_FINISH: begin
        // Assert finish write handshake (one cycle pulse)
        EN_finish_writing_prt_entry = 1'b1;
        next_state = S_EXTRACT_HEADER;
      end

      S_EXTRACT_HEADER: begin
        // Present the captured header on output for one cycle.
        get_header    = header_buffer;
        RDY_get_header= 1'b1;
        next_state    = S_SEND_HEADER;
      end

      S_SEND_HEADER: begin
        // Assert EN_send_header to initiate firewall header transfer.
        EN_send_header = 1'b1;
        // Wait for the handshake from firewall.
        if (RDY_send_header)
          next_state = S_WAIT_FIREWALL;
      end

      S_WAIT_FIREWALL: begin
        // Stay here until a firewall decision is available.
        // For simplicity, assume send_header_result is registered and valid here.
        next_state = S_DECIDE;
      end

      S_DECIDE: begin
        if (send_header_result == 1'b1)
          // Packet is safe; start reading payload.
          next_state = S_READ_PKT;
        else begin
          // Packet is unsafe; assert force stop and then invalidate the slot.
          force_stop_rx = 1'b1;
          next_state   = S_INVALIDATE;
        end
      end

      S_READ_PKT: begin
        // First, assert start_reading handshake (one cycle pulse)
        EN_start_reading_prt_entry = 1'b1;
        // Then, continuously read from the PRT.
        EN_read_prt_entry = 1'b1;
        // The PRT read data bus has an extra MSB flag indicating read completion.
        if (read_prt_entry[DATA_WIDTH])  // If the complete flag is high
          next_state = S_TRANSMIT_FINISH;
      end

      S_TRANSMIT_FINISH: begin
        // Transmission finished. In a real system, packet data would be sent via an AXI interface.
        next_state = S_DONE;
      end

      S_INVALIDATE: begin
        // Invalidate the PRT slot by asserting the handshake.
        EN_invalidate_prt_entry = 1'b1;
        next_state = S_DONE;
      end

      S_DONE: begin
        // Reset internal counters and return to idle.
        next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  //-------------------------------------------------------------------------
  // (Optional) Additional Logic: AXI Master interface signals, firewall enable handshake,
  // and other system integration details can be added below.
  // For this example, these signals are assigned to default inactive values.
  //-------------------------------------------------------------------------

endmodule
  /*
  The master_packet_dealer module is the top-level module that interfaces with the custom Ethernet IP. It receives incoming packets, processes them, and sends the header to the firewall for inspection. The module also includes a state machine to manage the packet processing flow. 
  The module includes the following interfaces: 
  
  Packet Reception Interface:  The module receives incoming packets from the custom Ethernet IP. The interface includes signals for packet validity, data, and the last byte of the frame. 
  Header Extraction Interface:  The module provides an interface to extract the header from the incoming packet. The header is captured and presented on the output interface. 
  Firewall Header Handshake Interface:  The module sends the header to the firewall for inspection. The interface includes signals for initiating the handshake, receiving the handshake response, and the firewall decision. 
  Firewall Enable Handshake Interface:  An optional interface to enable the firewall. The module provides signals to enable the firewall and receive the handshake response. 
  AXI Master Interface:  The module includes signals for an AXI master interface, which is not used in this example. 
  Force Stop Signal:  A signal to halt packet reception if the packet is deemed unsafe by the firewall. 
  
  The module also includes internal registers, counters, and a state machine to manage the packet processing flow. The state machine transitions through different states based on the packet processing stages. 
  The module uses the PRT_v2 module to manage the Packet Reference Table (PRT) for storing packet data. The PRT module handles write, read, and invalidate operations on the PRT slots. 
  The state machine controls the packet processing flow, including packet reception, header extraction, firewall inspection, and packet transmission. The module includes control logic to manage the state transitions and control signals for the PRT module. 
  The module also includes additional logic for the AXI master interface, firewall enable handshake, and other system integration details. In this example, these signals are assigned to default inactive values. 
  The master_packet_dealer module provides a high-level interface for packet processing and firewall inspection in a network system. The module manages the packet flow and interfaces with the custom Ethernet IP, firewall, and PRT module to process incoming packets. 
  3. PRT_v2 Module 
  The PRT_v2 module is responsible for managing the Packet Reference Table (PRT) in the packet processing system. The PRT stores packet data in slots and provides read, write, and invalidate operations
  */