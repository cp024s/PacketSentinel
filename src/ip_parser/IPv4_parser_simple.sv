module ethernet_parser (
    input  logic        clk,           // System clock
    input  logic        rst_n,         // Active-low reset
    input  logic        frame_valid,   // High when a new Ethernet frame is available
    input  logic [7:0]  frame_data,    // Incoming byte stream (1 byte per cycle)
    input  logic        frame_last,    // Indicates last byte of frame
    output logic [31:0] src_ip,        // Extracted Source IP Address
    output logic [31:0] dst_ip,        // Extracted Destination IP Address
    output logic        ip_valid       // High when IP extraction is complete
);

    typedef enum logic [2:0] {
        IDLE, READ_ETH, CHECK_IPV4, EXTRACT_IP, DONE
    } state_t;
    
    state_t state;
    logic [7:0] byte_counter;
    logic [15:0] ethertype;  // Stores EtherType field
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            byte_counter <= 0;
            src_ip      <= 0;
            dst_ip      <= 0;
            ethertype   <= 0;
            ip_valid    <= 0;
        end 
        else begin
            case (state)

                // **IDLE: Wait for a new frame to start**
                IDLE: begin
                    if (frame_valid) begin
                        byte_counter <= 0;
                        ip_valid    <= 0;
                        state       <= READ_ETH;
                    end
                end

                // **READ_ETH: Read Ethernet header (14 bytes)**
                READ_ETH: begin
                    byte_counter <= byte_counter + 1;
                    
                    // Capture EtherType (bytes 12-13)
                    if (byte_counter == 12) ethertype[15:8] <= frame_data;
                    if (byte_counter == 13) begin
                        ethertype[7:0] <= frame_data;
                        state <= CHECK_IPV4;
                    end
                end

                // **CHECK_IPV4: Verify if EtherType is IPv4 (0x0800)**
                CHECK_IPV4: begin
                    if (ethertype == 16'h0800) begin
                        state <= EXTRACT_IP;
                    end
                    else begin
                        state <= DONE;  // Not an IPv4 packet, ignore
                    end
                end

                // **EXTRACT_IP: Capture Source & Destination IP**
                EXTRACT_IP: begin
                    byte_counter <= byte_counter + 1;

                    // Extract Source IP (bytes 26-29)
                    if (byte_counter == 26) src_ip[31:24] <= frame_data;
                    if (byte_counter == 27) src_ip[23:16] <= frame_data;
                    if (byte_counter == 28) src_ip[15:8]  <= frame_data;
                    if (byte_counter == 29) src_ip[7:0]   <= frame_data;

                    // Extract Destination IP (bytes 30-33)
                    if (byte_counter == 30) dst_ip[31:24] <= frame_data;
                    if (byte_counter == 31) dst_ip[23:16] <= frame_data;
                    if (byte_counter == 32) dst_ip[15:8]  <= frame_data;
                    if (byte_counter == 33) begin
                        dst_ip[7:0] <= frame_data;
                        ip_valid    <= 1;  // Indicate that IP extraction is complete
                        state       <= DONE;
                    end
                end

                // **DONE: Hold values until reset or next frame**
                DONE: begin
                    if (!frame_valid) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
