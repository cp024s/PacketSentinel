module tb_ethernet_parser;

    logic clk, rst_n, frame_valid, frame_last;
    logic [7:0] frame_data;
    logic [31:0] src_ip, dst_ip;
    logic ip_valid;

    ethernet_parser uut (
        .clk(clk),
        .rst_n(rst_n),
        .frame_valid(frame_valid),
        .frame_data(frame_data),
        .frame_last(frame_last),
        .src_ip(src_ip),
        .dst_ip(dst_ip),
        .ip_valid(ip_valid)
    );

    always #5 clk = ~clk;  // Clock generation

    initial begin
        clk = 0;
        rst_n = 0;
        frame_valid = 0;
        frame_data = 0;
        frame_last = 0;
        #10 rst_n = 1;  // Release reset

        // Simulating Ethernet frame input
        frame_valid = 1;

        // Send Ethernet header (14 bytes)
        #10 frame_data = 8'h01;
        #10 frame_data = 8'h23;
        #10 frame_data = 8'h45;
        #10 frame_data = 8'h67;
        #10 frame_data = 8'h89;
        #10 frame_data = 8'hAB;  // Dest MAC
        #10 frame_data = 8'h12;
        #10 frame_data = 8'h34;
        #10 frame_data = 8'h56;
        #10 frame_data = 8'h78;
        #10 frame_data = 8'h9A;
        #10 frame_data = 8'hBC;  // Src MAC
        #10 frame_data = 8'h08;
        #10 frame_data = 8'h00;  // EtherType: IPv4

        // Send IPv4 header (20 bytes, skipping some fields)
        #10 frame_data = 8'h45;  // Version + IHL
        repeat(10) #10 frame_data = 8'h00;  // Skip unused fields
        #10 frame_data = 8'hC0;  // Source IP [192]
        #10 frame_data = 8'hA8;  // Source IP [168]
        #10 frame_data = 8'h01;  // Source IP [1]
        #10 frame_data = 8'h64;  // Source IP [100]
        #10 frame_data = 8'hC0;  // Dest IP [192]
        #10 frame_data = 8'hA8;  // Dest IP [168]
        #10 frame_data = 8'h01;  // Dest IP [1]
        #10 frame_data = 8'h01;  // Dest IP [1]
        #10 frame_valid = 0;     // End of frame

        #20;
        $display("Extracted Source IP: %h", src_ip);
        $display("Extracted Destination IP: %h", dst_ip);

        $stop;
    end
endmodule
