module ipv4_packet_filter (
    input  logic         clk,
    input  logic         rst,
    input  logic [31:0]  src_ip,
    input  logic [31:0]  dst_ip,
    output logic         block_packet
);

    // Parameters: number of stored IP addresses
    localparam int BRAM_DEPTH = 16;  

    // BRAM storage for blacklisted IPs
    logic [31:0] bram [0:BRAM_DEPTH-1];

    // Hardcoded IPs (example entries)
    initial begin
        bram[0] = 32'hC0A80001; // 192.168.0.1
        bram[1] = 32'hC0A80002; // 192.168.0.2
        bram[2] = 32'hC0A80003; // 192.168.0.3
        bram[3] = 32'hC0A80004; // 192.168.0.4
        // Remaining entries can be left as 0 or filled as needed.
    end

    // Search logic
    logic match_src, match_dst;
    integer i;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            match_src <= 1'b0;
            match_dst <= 1'b0;
        end else begin
            match_src = 1'b0;
            match_dst = 1'b0;
            for (i = 0; i < BRAM_DEPTH; i++) begin
                if (src_ip == bram[i])
                    match_src = 1'b1;
                if (dst_ip == bram[i])
                    match_dst = 1'b1;
            end
        end
    end

    // Block if either source or destination IP is blacklisted
    assign block_packet = match_src || match_dst;

endmodule
