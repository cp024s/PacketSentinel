module ethernet_parser (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] axis_tdata,
    input  logic       axis_tvalid,
    input  logic       axis_tlast,
    output logic       ip_valid,
    output logic [31:0] src_ip,
    output logic [31:0] dst_ip
);
    typedef enum logic [1:0] {IDLE, HEADER, DONE} state_t;
    state_t state, next_state;
    integer byte_cnt;

    // Temporary storage for IP bytes
    logic [7:0] src_ip_bytes [0:3];
    logic [7:0] dst_ip_bytes [0:3];

    // State update and byte counting
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            byte_cnt <= 0;
            ip_valid <= 1'b0;
        end else begin
            state <= next_state;
            if (axis_tvalid)
                byte_cnt <= byte_cnt + 1;
            else
                byte_cnt <= byte_cnt; // hold count when no valid data

            // Capture IP bytes when within expected byte ranges:
            // Source IP: bytes 26-29, Destination IP: bytes 30-33.
            if (axis_tvalid) begin
                if ((byte_cnt >= 26) && (byte_cnt < 30))
                    src_ip_bytes[byte_cnt-26] <= axis_tdata;
                else if ((byte_cnt >= 30) && (byte_cnt < 34))
                    dst_ip_bytes[byte_cnt-30] <= axis_tdata;
            end

            // Once we have parsed 34 bytes, output the IP addresses
            if (next_state == DONE) begin
                src_ip  <= {src_ip_bytes[0], src_ip_bytes[1], src_ip_bytes[2], src_ip_bytes[3]};
                dst_ip  <= {dst_ip_bytes[0], dst_ip_bytes[1], dst_ip_bytes[2], dst_ip_bytes[3]};
                ip_valid <= 1'b1;
            end else begin
                ip_valid <= 1'b0;
            end
        end
    end

    // Next-state logic: move to DONE after reading 34 bytes.
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (axis_tvalid) begin
                    next_state = HEADER;
                    byte_cnt = 0;
                end
            end
            HEADER: begin
                if (byte_cnt >= 34)
                    next_state = DONE;
            end
            DONE: begin
                // Wait until the end of the packet then return to IDLE.
                if (axis_tlast)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule
