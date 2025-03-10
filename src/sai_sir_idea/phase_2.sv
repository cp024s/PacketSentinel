module rgmii_rx (
  input  logic         clk,         // System clock: 125 MHz
  input  logic         rst_n,       // Active-low reset
  // RGMII signals from Ethernet port 1
  input  logic [3:0]   rgmii_rxd,
  input  logic         rgmii_rx_ctl,
  input  logic         rgmii_rxc,
  // AXI-stream style output
  output logic [7:0]   tdata,       // 8-bit data
  output logic         tvalid,      // Data valid signal
  output logic         tlast        // Asserted on last byte of frame
);

  //-------------------------------------------------------------------------
  // DDR Capture (using rising and falling edges of rgmii_rxc)
  // In real hardware, DDR input registers or dedicated primitives would be used.
  // Here we simulate DDR capture by sampling on both edges.
  //-------------------------------------------------------------------------
  logic [3:0] data_rise, data_fall;
  
  // Capture on rising edge
  always_ff @(posedge rgmii_rxc or negedge rst_n) begin
    if (!rst_n)
      data_rise <= 4'd0;
    else
      data_rise <= rgmii_rxd;
  end
  
  // Capture on falling edge
  always_ff @(negedge rgmii_rxc or negedge rst_n) begin
    if (!rst_n)
      data_fall <= 4'd0;
    else
      data_fall <= rgmii_rxd;
  end
  
  // Combine captured nibbles to form one byte.
  logic [7:0] byte_data;
  always_comb begin
    // In RGMII, the high nibble comes on the rising edge and the low nibble on the falling edge.
    byte_data = {data_rise, data_fall};
  end

  //-------------------------------------------------------------------------
  // Simple state machine to drive streaming interface.
  // When rgmii_rx_ctl is asserted, data are valid.
  // The falling edge of the control signal indicates the end of frame.
  //-------------------------------------------------------------------------
  typedef enum logic [1:0] {RX_IDLE, RX_ACTIVE} rx_state_t;
  rx_state_t state, next_state;
  
  // Register to detect control signal transition
  logic rx_ctl_d;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= RX_IDLE;
      rx_ctl_d   <= 1'b0;
    end else begin
      state      <= next_state;
      rx_ctl_d   <= rgmii_rx_ctl;
    end
  end
  
  always_comb begin
    // Defaults
    next_state = state;
    tvalid     = 1'b0;
    tdata      = 8'd0;
    tlast      = 1'b0;
    
    case (state)
      RX_IDLE: begin
        if (rgmii_rx_ctl) begin
          next_state = RX_ACTIVE;
          tvalid     = 1'b1;
          tdata      = byte_data;
        end
      end
      RX_ACTIVE: begin
        if (rgmii_rx_ctl) begin
          tvalid = 1'b1;
          tdata  = byte_data;
        end else begin
          // End of frame detected
          next_state = RX_IDLE;
          tlast      = 1'b1;
        end
      end
      default: next_state = RX_IDLE;
    endcase
  end

endmodule


module eth_parser (
  input  logic         clk,
  input  logic         rst_n,
  // AXI-stream input (from rgmii_rx)
  input  logic [7:0]   tdata,
  input  logic         tvalid,
  input  logic         tlast,
  // Parsed output: source and destination IPv4 addresses
  output logic [31:0]  src_ip,
  output logic [31:0]  dst_ip,
  output logic         ip_valid  // Asserted when both IP addresses have been captured
);

  // The expected byte positions:
  // Ethernet header: 14 bytes, then IP header.
  // In the IP header: source IP is at offset 12 and destination IP at offset 16.
  // Overall, source IP occupies bytes 26–29 and destination IP bytes 30–33.
  logic [7:0] byte_count;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      byte_count <= 8'd0;
      src_ip     <= 32'd0;
      dst_ip     <= 32'd0;
      ip_valid   <= 1'b0;
    end else begin
      if (tvalid) begin
        byte_count <= byte_count + 1;
        case (byte_count)
          8'd26: src_ip[31:24] <= tdata;
          8'd27: src_ip[23:16] <= tdata;
          8'd28: src_ip[15:8]  <= tdata;
          8'd29: src_ip[7:0]   <= tdata;
          8'd30: dst_ip[31:24] <= tdata;
          8'd31: dst_ip[23:16] <= tdata;
          8'd32: dst_ip[15:8]  <= tdata;
          8'd33: begin
                   dst_ip[7:0] <= tdata;
                   ip_valid    <= 1'b1;  // Both IP addresses have been captured.
                 end
          default: ; // Do nothing for other byte counts.
        endcase
      end
      
      // Reset the counter when the frame ends.
      if (tlast) begin
        byte_count <= 8'd0;
        ip_valid   <= 1'b0;
      end
    end
  end

endmodule


module bram_lookup #(
  parameter NUM_ENTRIES = 16
)(
  input  logic         clk,
  input  logic         rst_n,
  input  logic [31:0]  src_ip,
  input  logic [31:0]  dst_ip,
  input  logic         lookup_valid,  // Indicates valid IP addresses
  output logic         block          // Asserted if either IP is in the block list
);

  // Simple BRAM: array of blocked IPs.
  logic [31:0] block_list [0:NUM_ENTRIES-1];
  integer i;

  // For simulation, we initialize some entries.
  // In a real design you might load these from external memory or a configuration file.
  initial begin
    block_list[0] = 32'hC0A80101; // 192.168.1.1
    block_list[1] = 32'hC0A80102; // 192.168.1.2
    for (i = 2; i < NUM_ENTRIES; i = i + 1)
      block_list[i] = 32'h0;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      block <= 1'b0;
    else if (lookup_valid) begin
      block <= 1'b0;
      for (i = 0; i < NUM_ENTRIES; i = i + 1) begin
        if ((src_ip == block_list[i]) || (dst_ip == block_list[i]))
          block <= 1'b1;
      end
    end else
      block <= 1'b0;
  end

endmodule


module rgmii_tx (
  input  logic         clk,
  input  logic         rst_n,
  // AXI-stream input (packet to transmit)
  input  logic [7:0]   tdata,
  input  logic         tvalid,
  input  logic         tlast,
  // RGMII TX signals for Ethernet port 2
  output logic [3:0]   rgmii_txd,
  output logic         rgmii_tx_ctl,
  output logic         rgmii_txc
);

  // For this example, we derive the TX clock from the system clock.
  assign rgmii_txc = clk;

  // Split tdata into two 4-bit nibbles.
  logic [3:0] data_rise, data_fall;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      data_rise <= 4'd0;
    else if (tvalid)
      data_rise <= tdata[7:4];
  end
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      data_fall <= 4'd0;
    else if (tvalid)
      data_fall <= tdata[3:0];
  end
  
  // For simulation purposes we simply drive the output with the high nibble.
  // In actual hardware, DDR output registers would ensure both nibbles are sent.
  assign rgmii_txd    = data_rise;
  assign rgmii_tx_ctl = tvalid;

endmodule


module frame_fifo (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         write_en,
  input  logic [7:0]   write_data,
  input  logic         read_en,
  output logic [7:0]   read_data,
  output logic         empty,
  output logic         full
);
  parameter DEPTH = 2048;
  localparam ADDR_WIDTH = $clog2(DEPTH);
  
  logic [7:0] mem [0:DEPTH-1];
  logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
  logic [ADDR_WIDTH:0] count;
  
  // Write process
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= 0;
      count  <= 0;
    end else if (write_en && !full) begin
      mem[wr_ptr] <= write_data;
      wr_ptr <= wr_ptr + 1;
      count  <= count + 1;
    end
  end
  
  // Read process
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_ptr <= 0;
    end else if (read_en && !empty) begin
      rd_ptr <= rd_ptr + 1;
      count  <= count - 1;
    end
  end
  
  assign read_data = mem[rd_ptr];
  assign empty = (count == 0);
  assign full  = (count == DEPTH);

endmodule


module packet_fsm (
  input  logic         clk,
  input  logic         rst_n,
  // Input stream from RX
  input  logic [7:0]   rx_data,
  input  logic         rx_valid,
  input  logic         rx_last,
  // Parser outputs (assumed to be tapped from the same stream)
  input  logic [31:0]  src_ip,
  input  logic [31:0]  dst_ip,
  input  logic         ip_valid,
  // BRAM lookup result
  input  logic         block,
  // Output stream to TX
  output logic [7:0]   tx_data,
  output logic         tx_valid,
  output logic         tx_last
);

  typedef enum logic [2:0] {
    IDLE,
    RECEIVE,
    WAIT_PARSE,
    WAIT_LOOKUP,
    FORWARD,
    DROP
  } fsm_state_t;
  
  fsm_state_t state, next_state;
  
  // Instantiate a FIFO to buffer the entire frame.
  logic         fifo_write_en, fifo_read_en;
  logic [7:0]   fifo_read_data;
  logic         fifo_empty, fifo_full;
  
  frame_fifo fifo_inst (
    .clk       (clk),
    .rst_n     (rst_n),
    .write_en  (fifo_write_en),
    .write_data(rx_data),
    .read_en   (fifo_read_en),
    .read_data (fifo_read_data),
    .empty     (fifo_empty),
    .full      (fifo_full)
  );
  
  // FSM: 
  // IDLE: Wait for the start of a new frame.
  // RECEIVE: Buffer incoming data into the FIFO.
  // WAIT_PARSE: Wait until the parser has extracted IP addresses.
  // WAIT_LOOKUP: Decide based on BRAM lookup (block or allow).
  // FORWARD: Read from FIFO and send data to TX.
  // DROP: Flush/discard FIFO contents.
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end
  
  always_comb begin
    // Default assignments
    next_state      = state;
    fifo_write_en   = 1'b0;
    fifo_read_en    = 1'b0;
    tx_data         = 8'd0;
    tx_valid        = 1'b0;
    tx_last         = 1'b0;
    
    case (state)
      IDLE: begin
        // Wait for a new frame (rx_valid goes high)
        if (rx_valid) begin
          next_state    = RECEIVE;
          fifo_write_en = rx_valid;
        end
      end
      RECEIVE: begin
        // Buffer incoming data. The parser is assumed to “tap” the same stream.
        fifo_write_en = rx_valid;
        if (rx_last) begin
          next_state = WAIT_PARSE;
        end
      end
      WAIT_PARSE: begin
        // Wait until the parser has provided valid IP addresses.
        if (ip_valid)
          next_state = WAIT_LOOKUP;
      end
      WAIT_LOOKUP: begin
        // Make decision based on BRAM lookup result.
        if (block)
          next_state = DROP;
        else
          next_state = FORWARD;
      end
      FORWARD: begin
        // Read from FIFO and forward out.
        if (!fifo_empty) begin
          fifo_read_en = 1'b1;
          tx_data      = fifo_read_data;
          tx_valid     = 1'b1;
          // For simplicity, we assume that when the FIFO is empty, we reached frame end.
          if (fifo_empty)
            tx_last = 1'b1;
        end else begin
          next_state = IDLE;
        end
      end
      DROP: begin
        // Discard the contents of the FIFO.
        if (!fifo_empty)
          fifo_read_en = 1'b1;
        else
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule


module packet_processor (
  input  logic         clk,           // 125 MHz system clock
  input  logic         rst_n,
  // RGMII RX interface (port 1)
  input  logic [3:0]   rgmii_rx_data,
  input  logic         rgmii_rx_ctl,
  input  logic         rgmii_rx_clk,
  // RGMII TX interface (port 2)
  output logic [3:0]   rgmii_tx_data,
  output logic         rgmii_tx_ctl,
  output logic         rgmii_tx_clk
);

  //--------------------------------------------------------------------------
  // Stage 1: Receive packet from first Ethernet port.
  //--------------------------------------------------------------------------
  logic [7:0] rx_stream_data;
  logic       rx_stream_valid;
  logic       rx_stream_last;
  
  rgmii_rx rx_inst (
    .clk         (clk),
    .rst_n       (rst_n),
    .rgmii_rxd   (rgmii_rx_data),
    .rgmii_rx_ctl(rgmii_rx_ctl),
    .rgmii_rxc   (rgmii_rx_clk),
    .tdata       (rx_stream_data),
    .tvalid      (rx_stream_valid),
    .tlast       (rx_stream_last)
  );
  
  //--------------------------------------------------------------------------
  // Stage 2: Extract IPv4 source and destination addresses.
  //--------------------------------------------------------------------------
  logic [31:0] src_ip;
  logic [31:0] dst_ip;
  logic        ip_valid;
  
  eth_parser parser_inst (
    .clk    (clk),
    .rst_n  (rst_n),
    .tdata  (rx_stream_data),
    .tvalid (rx_stream_valid),
    .tlast  (rx_stream_last),
    .src_ip (src_ip),
    .dst_ip (dst_ip),
    .ip_valid(ip_valid)
  );
  
  //--------------------------------------------------------------------------
  // Stage 3: BRAM lookup for IP blocking.
  //--------------------------------------------------------------------------
  logic block;
  
  bram_lookup bram_inst (
    .clk          (clk),
    .rst_n        (rst_n),
    .src_ip       (src_ip),
    .dst_ip       (dst_ip),
    .lookup_valid (ip_valid),
    .block        (block)
  );
  
  //--------------------------------------------------------------------------
  // Stage 4: Packet FSM to buffer and decide on forwarding/dropping.
  //--------------------------------------------------------------------------
  logic [7:0] tx_stream_data;
  logic       tx_stream_valid;
  logic       tx_stream_last;
  
  packet_fsm fsm_inst (
    .clk      (clk),
    .rst_n    (rst_n),
    .rx_data  (rx_stream_data),
    .rx_valid (rx_stream_valid),
    .rx_last  (rx_stream_last),
    .src_ip   (src_ip),
    .dst_ip   (dst_ip),
    .ip_valid (ip_valid),
    .block    (block),
    .tx_data  (tx_stream_data),
    .tx_valid (tx_stream_valid),
    .tx_last  (tx_stream_last)
  );
  
  //--------------------------------------------------------------------------
  // Stage 5: Transmit allowed packet via second Ethernet port.
  //--------------------------------------------------------------------------
  rgmii_tx tx_inst (
    .clk         (clk),
    .rst_n       (rst_n),
    .tdata       (tx_stream_data),
    .tvalid      (tx_stream_valid),
    .tlast       (tx_stream_last),
    .rgmii_txd   (rgmii_tx_data),
    .rgmii_tx_ctl(rgmii_tx_ctl),
    .rgmii_txc   (rgmii_tx_clk)
  );

endmodule


