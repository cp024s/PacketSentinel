module ipv4_packet_filter #(
    parameter integer BRAM_DEPTH = 16  // Number of stored IP addresses
)(
    input  logic         clk,       // System clock
    input  logic         rst,       // Asynchronous reset
    input  logic [31:0]  src_ip,    // Source IP address from incoming packet
    input  logic [31:0]  dst_ip,    // Destination IP address from incoming packet
    output logic         block_packet // High if either IP is blacklisted
);

    // ----------------------------------------------------------------
    // BRAM Memory: Store the blacklist IP addresses.
    // Optionally, you can load from an external file using $readmemh.
    // For now, hardcoded values are used.
    // ----------------------------------------------------------------
    logic [31:0] bram [0:BRAM_DEPTH-1];

    // Hardcode some IP addresses in the BRAM
    initial begin
        bram[0] = 32'hC0A80001; // 192.168.0.1
        bram[1] = 32'hC0A80002; // 192.168.0.2
        bram[2] = 32'hC0A80003; // 192.168.0.3
        bram[3] = 32'hC0A80004; // 192.168.0.4
        // Initialize remaining entries to zero (or add more IPs as needed)
        for (int i = 4; i < BRAM_DEPTH; i++) begin
            bram[i] = 32'd0;
        end
    end

    // ----------------------------------------------------------------
    // Combinational Matching Logic:
    // Check if either the source or destination IP matches any
    // of the entries in the BRAM.
    // ----------------------------------------------------------------
    logic match_found;

    always_comb begin
        match_found = 1'b0;
        for (int i = 0; i < BRAM_DEPTH; i++) begin
            // If either IP matches, set match_found high
            if ((src_ip == bram[i]) || (dst_ip == bram[i])) begin
                match_found = 1'b1;
            end
        end
    end

    // ----------------------------------------------------------------
    // Synchronous Output:
    // Register the match result to create the block_packet signal.
    // ----------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            block_packet <= 1'b0;
        else
            block_packet <= match_found;
    end

endmodule


module ethernet_parser (
    input  logic       clk,         // System clock
    input  logic       rst,         // Asynchronous reset
    input  logic [7:0] axis_tdata,  // AXI-Stream data from RX module
    input  logic       axis_tvalid, // Data valid signal
    input  logic       axis_tlast,  // End-of-frame indicator
    output logic       ip_valid,    // Indicates that IP addresses are valid
    output logic [31:0] src_ip,     // Extracted source IP address
    output logic [31:0] dst_ip      // Extracted destination IP address
);

    // -------------------------------------------------------------
    // State machine definition for packet parsing.
    // -------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE,      // Waiting for the start of a packet
        CAPTURING, // Actively capturing bytes
        DONE       // Extraction complete; waiting for end-of-frame
    } state_t;
    state_t state, next_state;

    // -------------------------------------------------------------
    // Byte counter for tracking our position within the packet.
    // -------------------------------------------------------------
    logic [5:0] byte_count;

    // -------------------------------------------------------------
    // Registers for storing individual bytes of the IP addresses.
    // -------------------------------------------------------------
    logic [7:0] src_ip_bytes [0:3];
    logic [7:0] dst_ip_bytes [0:3];

    // -------------------------------------------------------------
    // Sequential block: state and byte counter update, and IP capture.
    // -------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            byte_count <= 6'd0;
            ip_valid   <= 1'b0;
        end else begin
            state <= next_state;
            // Only increment byte counter when valid data is present
            if (axis_tvalid)
                byte_count <= byte_count + 1;
            
            // Capture the IP address bytes based on known offsets.
            // Source IP: bytes 26-29 (i.e., when byte_count is 26 to 29)
            if (axis_tvalid && (byte_count >= 6'd26) && (byte_count < 6'd30))
                src_ip_bytes[byte_count - 6'd26] <= axis_tdata;
            
            // Destination IP: bytes 30-33 (i.e., when byte_count is 30 to 33)
            if (axis_tvalid && (byte_count >= 6'd30) && (byte_count < 6'd34))
                dst_ip_bytes[byte_count - 6'd30] <= axis_tdata;
            
            // When reaching the DONE state, update the output IP addresses.
            if (next_state == DONE) begin
                src_ip  <= {src_ip_bytes[0], src_ip_bytes[1], src_ip_bytes[2], src_ip_bytes[3]};
                dst_ip  <= {dst_ip_bytes[0], dst_ip_bytes[1], dst_ip_bytes[2], dst_ip_bytes[3]};
                ip_valid <= 1'b1;
            end else begin
                ip_valid <= 1'b0;
            end
            
            // If we see the last byte of the packet, reset the counter for the next frame.
            if (axis_tlast)
                byte_count <= 6'd0;
        end
    end

    // -------------------------------------------------------------
    // Next-state combinational logic.
    // -------------------------------------------------------------
    always_comb begin
        // Default to current state
        next_state = state;
        case (state)
            IDLE: begin
                // Wait for start of packet. Transition to CAPTURING when valid data arrives.
                if (axis_tvalid)
                    next_state = CAPTURING;
            end
            CAPTURING: begin
                // Once we've captured the necessary 34 bytes, move to DONE.
                if (byte_count >= 6'd34)
                    next_state = DONE;
            end
            DONE: begin
                // Stay in DONE until the frame ends, then return to IDLE.
                if (axis_tlast)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule


module packet_decision #(
    parameter integer MAX_PKT_SIZE = 512  // Maximum packet size (in bytes)
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       block_packet,  // Decision signal: 1=drop, 0=forward
    // AXI-Stream input interface (incoming packet)
    input  logic [7:0] axis_in_tdata,
    input  logic       axis_in_tvalid,
    input  logic       axis_in_tlast,
    // AXI-Stream output interface (to be sent out if allowed)
    output logic [7:0] axis_out_tdata,
    output logic       axis_out_tvalid,
    output logic       axis_out_tlast
);

    // ------------------------------------------------------------
    // State Machine Declaration
    // ------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE,    // Waiting for start of packet
        CAPTURE, // Buffering incoming packet data
        OUTPUT,  // Forwarding packet data out
        DROP     // Dropping (flushing) the packet
    } state_t;
    state_t state, next_state;

    // ------------------------------------------------------------
    // FIFO Declarations for Packet Buffering
    // ------------------------------------------------------------
    localparam integer PTR_WIDTH = $clog2(MAX_PKT_SIZE);
    logic [7:0] fifo_mem [0:MAX_PKT_SIZE-1];  // FIFO memory array
    logic [PTR_WIDTH-1:0] wr_ptr, rd_ptr;       // Write and read pointers
    logic [PTR_WIDTH:0] fifo_count;             // Number of bytes stored

    // ------------------------------------------------------------
    // Latch for current packet decision.
    // ------------------------------------------------------------
    logic current_block;

    // ------------------------------------------------------------
    // State Machine: Capture and Process Packet
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= IDLE;
            wr_ptr      <= '0;
            rd_ptr      <= '0;
            fifo_count  <= 0;
            current_block <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    // Wait for the start of a packet
                    if (axis_in_tvalid) begin
                        // Initialize pointers and latch the block decision
                        wr_ptr     <= '0;
                        rd_ptr     <= '0;
                        fifo_count <= 0;
                        current_block <= block_packet;
                    end
                end

                CAPTURE: begin
                    // While receiving valid data, store it into FIFO
                    if (axis_in_tvalid) begin
                        fifo_mem[wr_ptr] <= axis_in_tdata;
                        wr_ptr <= wr_ptr + 1;
                        fifo_count <= fifo_count + 1;
                    end
                end

                OUTPUT: begin
                    // In OUTPUT state, we simply advance the read pointer
                    // when data is being output (see output logic below)
                    if (axis_out_tvalid && axis_out_tlast) begin
                        // After the last byte is output, reset pointers
                        rd_ptr <= '0;
                        wr_ptr <= '0;
                        fifo_count <= 0;
                    end
                end

                DROP: begin
                    // In DROP state, flush the packet (ignore FIFO contents)
                    // Once the packet is fully captured, we can simply reset.
                    rd_ptr <= '0;
                    wr_ptr <= '0;
                    fifo_count <= 0;
                end

                default: ; 
            endcase
        end
    end

    // ------------------------------------------------------------
    // Next-State Combinational Logic
    // ------------------------------------------------------------
    always_comb begin
        // Default assignment for next state is the current state.
        next_state = state;
        case (state)
            IDLE: begin
                // When valid data arrives, start capturing.
                if (axis_in_tvalid)
                    next_state = CAPTURE;
            end

            CAPTURE: begin
                // Continue capturing until we see the end-of-packet.
                if (axis_in_tlast) begin
                    // Latch decision has already been captured at the start.
                    // Transition based on whether the packet should be dropped.
                    if (current_block)
                        next_state = DROP;
                    else
                        next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                // Remain in OUTPUT state until all buffered data is sent out.
                // We know the packet is complete when fifo_count equals 0.
                if (fifo_count == 0)
                    next_state = IDLE;
            end

            DROP: begin
                // After dropping, immediately return to IDLE.
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // ------------------------------------------------------------
    // Output Logic for AXI-Stream Interface
    // ------------------------------------------------------------
    // This block drives the output signals from the FIFO during OUTPUT state.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            axis_out_tdata  <= 8'd0;
            axis_out_tvalid <= 1'b0;
            axis_out_tlast  <= 1'b0;
        end else begin
            if (state == OUTPUT) begin
                // Drive output from FIFO memory.
                axis_out_tdata  <= fifo_mem[rd_ptr];
                axis_out_tvalid <= 1'b1;
                // Assert tlast when we output the last byte.
                if (fifo_count == 1)
                    axis_out_tlast <= 1'b1;
                else
                    axis_out_tlast <= 1'b0;
            end else begin
                axis_out_tdata  <= 8'd0;
                axis_out_tvalid <= 1'b0;
                axis_out_tlast  <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------
    // Read Pointer and FIFO Count Update for OUTPUT State
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rd_ptr     <= '0;
            fifo_count <= 0;
        end else begin
            if (state == OUTPUT && axis_out_tvalid) begin
                // Advance the read pointer after each output byte.
                rd_ptr <= rd_ptr + 1;
                fifo_count <= fifo_count - 1;
            end
        end
    end

endmodule


module rgmii_rx_module (
    input  logic         rgmii_rxclk, // RX clock from PHY (e.g., 125 MHz)
    input  logic [3:0]   rgmii_rxd,   // 4-bit data from PHY
    input  logic         rgmii_rxctl, // RX control signal from PHY (indicates data validity)
    input  logic         rst,         // Asynchronous reset
    output logic [7:0]   axis_tdata,  // AXI-Stream output data (8-bit)
    output logic         axis_tvalid, // AXI-Stream data valid signal
    output logic         axis_tlast   // AXI-Stream end-of-frame indicator
);

    // ----------------------------------------------------------------
    // RGMII Data Sampling on Both Edges
    // ----------------------------------------------------------------
    // In RGMII, data is transmitted on both rising and falling edges.
    // Here we sample data separately.
    logic [3:0] data_rise;  // Data captured on rising edge
    logic [3:0] data_fall;  // Data captured on falling edge
    logic       dv_rise;    // Data valid sampled on rising edge
    logic       dv_fall;    // Data valid sampled on falling edge

    // Sample on rising edge of rgmii_rxclk
    always_ff @(posedge rgmii_rxclk or posedge rst) begin
        if (rst) begin
            data_rise <= 4'd0;
            dv_rise   <= 1'b0;
        end else begin
            data_rise <= rgmii_rxd;
            dv_rise   <= rgmii_rxctl;
        end
    end

    // Sample on falling edge of rgmii_rxclk
    always_ff @(negedge rgmii_rxclk or posedge rst) begin
        if (rst) begin
            data_fall <= 4'd0;
            dv_fall   <= 1'b0;
        end else begin
            data_fall <= rgmii_rxd;
            dv_fall   <= rgmii_rxctl;
        end
    end

    // ----------------------------------------------------------------
    // Combine Rising and Falling Data into an 8-bit Word
    // ----------------------------------------------------------------
    // Conventionally, the rising edge nibble forms the high 4 bits and
    // the falling edge nibble forms the low 4 bits.
    logic [7:0] combined_byte;
    assign combined_byte = {data_rise, data_fall};

    // ----------------------------------------------------------------
    // Generate a "Byte Ready" Signal using a Toggle Mechanism
    // ----------------------------------------------------------------
    // Since an 8-bit word is formed over two edges, we use a toggle
    // that flips every rising edge when data is valid.
    logic toggle;
    always_ff @(posedge rgmii_rxclk or posedge rst) begin
        if (rst)
            toggle <= 1'b0;
        else if (dv_rise) // Only toggle when valid data is present
            toggle <= ~toggle;
    end
    // The 'toggle' signal is high every other rising edge, indicating a complete byte.
    wire byte_ready = toggle & dv_rise;

    // ----------------------------------------------------------------
    // End-of-Frame Detection
    // ----------------------------------------------------------------
    // Capture the previous value of dv_rise to detect a falling edge of the
    // data valid signal, which indicates the end of a frame.
    logic dv_rise_prev;
    always_ff @(posedge rgmii_rxclk or posedge rst) begin
        if (rst)
            dv_rise_prev <= 1'b0;
        else
            dv_rise_prev <= dv_rise;
    end

    // ----------------------------------------------------------------
    // AXI-Stream Output Generation
    // ----------------------------------------------------------------
    // When a complete byte is ready, output the combined byte along with
    // valid and last indicators. The axis_tlast signal is asserted when
    // dv_rise transitions from high to low (end-of-frame).
    always_ff @(posedge rgmii_rxclk or posedge rst) begin
        if (rst) begin
            axis_tdata  <= 8'd0;
            axis_tvalid <= 1'b0;
            axis_tlast  <= 1'b0;
        end else begin
            if (byte_ready) begin
                axis_tdata  <= combined_byte;
                axis_tvalid <= 1'b1;
                // Detect end-of-frame: if dv_rise was high in the previous cycle and now low.
                if (dv_rise_prev && !dv_rise)
                    axis_tlast <= 1'b1;
                else
                    axis_tlast <= 1'b0;
            end else begin
                axis_tvalid <= 1'b0;
                axis_tlast  <= 1'b0;
            end
        end
    end

endmodule


module rgmii_tx_module (
    input  logic        clk,           // System clock (TX clock, e.g., 125 MHz)
    input  logic        rst,           // Asynchronous reset
    input  logic [7:0]  axis_tdata,    // AXI-Stream input data (8-bit word)
    input  logic        axis_tvalid,   // AXI-Stream valid signal
    input  logic        axis_tlast,    // AXI-Stream end-of-frame indicator
    output logic [3:0]  rgmii_txd,     // 4-bit RGMII TX data output
    output logic        rgmii_txctl,   // RGMII TX control signal (data valid)
    output logic        rgmii_txclk    // RGMII TX clock output (buffered clk)
);

    // ------------------------------------------------------------
    // Data Buffering and Splitting:
    // Latch the AXI-Stream data when valid, then split the byte into:
    // • High nibble: axis_tdata[7:4]
    // • Low nibble:  axis_tdata[3:0]
    // ------------------------------------------------------------
    logic [7:0] data_buffer;
    logic       data_buffer_valid;
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            data_buffer       <= 8'd0;
            data_buffer_valid <= 1'b0;
        end else begin
            // Latch the new byte when valid
            if (axis_tvalid)
                data_buffer <= axis_tdata;
            data_buffer_valid <= axis_tvalid;
        end
    end

    wire [3:0] high_nibble = data_buffer[7:4];
    wire [3:0] low_nibble  = data_buffer[3:0];

    // ------------------------------------------------------------
    // DDR Output for Data (rgmii_txd):
    // In RGMII, data is transmitted on both rising and falling edges:
    // - Rising edge: high nibble is transmitted.
    // - Falling edge: low nibble is transmitted.
    //
    // For simulation, we provide a behavioral model.
    // In synthesis, replace the following behavior with ODDR primitives.
    // ------------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin: ddr_data_out
            // Behavioral DDR model for each bit.
            // On synthesis, instantiate an ODDR (or similar) as:
            // ODDR #(
            //     .DDR_CLK_EDGE("SAME_EDGE"),
            //     .INIT(1'b0),
            //     .SRTYPE("SYNC")
            // ) oddr_inst (
            //     .Q(rgmii_txd[i]),
            //     .C(clk),
            //     .CE(1'b1),
            //     .D1(high_nibble[i]),
            //     .D2(low_nibble[i]),
            //     .R(rst),
            //     .S(1'b0)
            // );
            // For behavioral simulation, we simply assign the high nibble on posedge.
            always_ff @(posedge clk or posedge rst) begin
                if (rst)
                    rgmii_txd[i] <= 1'b0;
                else if (data_buffer_valid)
                    rgmii_txd[i] <= high_nibble[i];
            end
        end
    endgenerate

    // ------------------------------------------------------------
    // DDR Output for TX Control Signal (rgmii_txctl):
    // Similar to data, the control signal should be DDR driven.
    // For simplicity, we assume the control signal is high when data is valid.
    // In synthesis, use an ODDR to drive rgmii_txctl with the same concept.
    // ------------------------------------------------------------
    logic txctl_rising, txctl_falling;
    
    // Rising edge sampling for tx control
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            txctl_rising <= 1'b0;
        else
            txctl_rising <= data_buffer_valid;
    end
    
    // Falling edge sampling for tx control
    always_ff @(negedge clk or posedge rst) begin
        if (rst)
            txctl_falling <= 1'b0;
        else
            txctl_falling <= data_buffer_valid;
    end
    
    // Behavioral assignment: output the rising edge value.
    // In a real design, use an ODDR to combine txctl_rising and txctl_falling.
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            rgmii_txctl <= 1'b0;
        else
            rgmii_txctl <= txctl_rising;
    end

    // ------------------------------------------------------------
    // TX Clock Generation:
    // For RGMII, the TX clock is typically a buffered version of the system clock.
    // ------------------------------------------------------------
    assign rgmii_txclk = clk;

endmodule


`timescale 1ns / 1ps
module ethernet_filter_top (
    input  logic         clk,          // System clock for logic and AXI-stream interfaces
    input  logic         rst,          // Asynchronous reset
    // RGMII RX interface for input Ethernet port (port 1)
    input  logic [3:0]   rgmii_rxd,    // 4-bit data from PHY (RX)
    input  logic         rgmii_rxctl,  // RX control signal from PHY (indicates valid data)
    input  logic         rgmii_rxclk,  // RX clock from PHY (e.g., 125 MHz)
    // RGMII TX interface for output Ethernet port (port 2)
    output logic [3:0]   rgmii_txd,    // 4-bit data to PHY (TX)
    output logic         rgmii_txctl,  // TX control signal for PHY
    output logic         rgmii_txclk   // TX clock output (buffered version of clk)
);

    // ------------------------------------------------------------
    // AXI-Stream signals from the RGMII RX module.
    // ------------------------------------------------------------
    wire [7:0] rx_axis_tdata;
    wire       rx_axis_tvalid;
    wire       rx_axis_tlast;

    // ------------------------------------------------------------
    // Instantiate the RGMII RX Module:
    // Converts RGMII signals to an 8-bit AXI-Stream interface.
    // ------------------------------------------------------------
    rgmii_rx_module u_rgmii_rx (
        .rgmii_rxclk (rgmii_rxclk),
        .rgmii_rxd   (rgmii_rxd),
        .rgmii_rxctl (rgmii_rxctl),
        .rst         (rst),
        .axis_tdata  (rx_axis_tdata),
        .axis_tvalid (rx_axis_tvalid),
        .axis_tlast  (rx_axis_tlast)
    );

    // ------------------------------------------------------------
    // Ethernet Parser:
    // Extracts the source and destination IP addresses from the AXI-Stream data.
    // ------------------------------------------------------------
    wire        ip_valid;
    wire [31:0] src_ip;
    wire [31:0] dst_ip;
    ethernet_parser u_eth_parser (
        .clk         (clk),
        .rst         (rst),
        .axis_tdata  (rx_axis_tdata),
        .axis_tvalid (rx_axis_tvalid),
        .axis_tlast  (rx_axis_tlast),
        .ip_valid    (ip_valid),
        .src_ip      (src_ip),
        .dst_ip      (dst_ip)
    );

    // ------------------------------------------------------------
    // IPv4 Packet Filter:
    // Checks both source and destination IP addresses against a hardcoded BRAM.
    // Generates a block signal if a match is found.
    // ------------------------------------------------------------
    wire block_packet;
    ipv4_packet_filter u_ip_filter (
        .clk         (clk),
        .rst         (rst),
        .src_ip      (src_ip),
        .dst_ip      (dst_ip),
        .block_packet(block_packet)
    );

    // ------------------------------------------------------------
    // Packet Decision Module:
    // Buffers the incoming packet and, based on the block decision,
    // either passes it through or drops it.
    // ------------------------------------------------------------
    wire [7:0] tx_axis_tdata;
    wire       tx_axis_tvalid;
    wire       tx_axis_tlast;
    packet_decision u_packet_decision (
        .clk             (clk),
        .rst             (rst),
        .block_packet    (block_packet),
        .axis_in_tdata   (rx_axis_tdata),
        .axis_in_tvalid  (rx_axis_tvalid),
        .axis_in_tlast   (rx_axis_tlast),
        .axis_out_tdata  (tx_axis_tdata),
        .axis_out_tvalid (tx_axis_tvalid),
        .axis_out_tlast  (tx_axis_tlast)
    );

    // ------------------------------------------------------------
    // RGMII TX Module:
    // Converts the approved 8-bit AXI-Stream data to RGMII signals,
    // splitting data into two 4-bit nibbles with DDR behavior.
    // ------------------------------------------------------------
    rgmii_tx_module u_rgmii_tx (
        .clk         (clk),
        .rst         (rst),
        .axis_tdata  (tx_axis_tdata),
        .axis_tvalid (tx_axis_tvalid),
        .axis_tlast  (tx_axis_tlast),
        .rgmii_txd   (rgmii_txd),
        .rgmii_txctl (rgmii_txctl),
        .rgmii_txclk (rgmii_txclk)
    );

endmodule
