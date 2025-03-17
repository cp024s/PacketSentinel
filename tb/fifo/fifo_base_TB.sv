`timescale 1ns/1ps

module fifo_tb;
    // Parameters
    parameter DATA_WIDTH = 32;
    parameter FIFO_DEPTH = 16;
    parameter ADDR_WIDTH = $clog2(FIFO_DEPTH);

    // Signals
    reg clk, rst;
    reg wr_en, rd_en;
    reg [DATA_WIDTH-1:0] din;
    wire [DATA_WIDTH-1:0] dout;
    wire full, empty;

    // Instantiate FIFO
    fifo #(.DATA_WIDTH(DATA_WIDTH), .FIFO_DEPTH(FIFO_DEPTH)) dut (
        .clk(clk), .rst(rst), .wr_en(wr_en), .rd_en(rd_en),
        .din(din), .dout(dout), .full(full), .empty(empty)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Testbench Task: Write Data
    task write_data(input [DATA_WIDTH-1:0] data);
        if (!full) begin
            din = data;
            wr_en = 1;
            @(posedge clk);
            wr_en = 0;
            $display("[%0t] Wrote Data: %h", $time, data);
        end else begin
            $display("[%0t] FIFO Full! Write Skipped.", $time);
        end
    endtask

    // Testbench Task: Read Data
    task read_data;
        if (!empty) begin
            rd_en = 1;
            @(posedge clk);
            rd_en = 0;
            $display("[%0t] Read Data: %h", $time, dout);
        end else begin
            $display("[%0t] FIFO Empty! Read Skipped.", $time);
        end
    endtask

    // Testbench Task: Reset FIFO
    task reset_fifo;
        $display("[%0t] Resetting FIFO", $time);
        rst = 1;
        @(posedge clk);
        rst = 0;
    endtask

    // Main Test Sequence
    initial begin
        // Initialize signals
        clk = 0; rst = 1;
        wr_en = 0; rd_en = 0;
        din = 0;
        
        // Reset FIFO
        reset_fifo();
        
        // Test 1: Write and Read Single Value
        write_data(32'hA5A5A5A5);
        read_data();
        
        // Test 2: Fill the FIFO completely
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            write_data(i);
        end
        
        // Test 3: Read all data back
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            read_data();
        end
        
        // Test 4: Underflow scenario
        read_data();
        
        // Test 5: Overflow scenario
        for (int i = 0; i < FIFO_DEPTH + 2; i++) begin
            write_data(i * 16'h1111);
        end
        
        // Test 6: Alternating Write/Read
        for (int i = 0; i < 10; i++) begin
            write_data(i * 8'h0F);
            read_data();
        end
        
        // Test 7: Randomized Burst Write/Read
        for (int i = 0; i < 20; i++) begin
            if ($random % 2)
                write_data($random);
            else
                read_data();
        end
        
        // Test 8: Reset and Verify Empty State
        reset_fifo();
        read_data();
        
        $display("[%0t] Test Completed!", $time);
        $finish;
    end
endmodule
