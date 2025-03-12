    `timescale 1ns/1ps
module tb_PRT;

  // Clock and signal declarations
  reg         clka, clkb;
  reg         wea, web;
  reg  [15:0] addra, addrb;
  reg         dina, dinb;
  wire        douta, doutb;

  // Instantiate the BRAM IP
  PRT PRT_inst (
    .clka(clka),    // port A clock
    .wea(wea),      // port A write enable
    .addra(addra),  // port A address
    .dina(dina),    // port A data input
    .douta(douta),  // port A data output
    .clkb(clkb),    // port B clock
    .web(web),      // port B write enable
    .addrb(addrb),  // port B address
    .dinb(dinb),    // port B data input
    .doutb(doutb)   // port B data output
  );

  // Generate clka: 10ns period
  initial begin
    clka = 0;
    forever #5 clka = ~clka;
  end

  // Generate clkb: 14ns period
  initial begin
    clkb = 0;
    forever #7 clkb = ~clkb;
  end

  // Optional: monitor key signals during simulation
  initial begin
    $monitor("Time=%0t | clka=%b addra=%h wea=%b dina=%b douta=%b || clkb=%b addrb=%h web=%b dinb=%b doutb=%b",
             $time, clka, addra, wea, dina, douta, clkb, addrb, web, dinb, doutb);
  end

  // Stimulus: applying a series of test cases
  initial begin
    // Initialize all signals
    wea   = 1'b0;
    web   = 1'b0;
    addra = 16'h0000;
    addrb = 16'h0000;
    dina  = 1'b0;
    dinb  = 1'b0;
    
    // Wait for global reset (if any)
    #20;
    
    // ---------------------------------------------------------------------
    // Test 1: Basic Write and Read on Port A 
    // Write a '1' to address 16'h0001 using port A and then read it back.
    // Note: due to 2-cycle latency, the output will update after 2 clka edges.
    // ---------------------------------------------------------------------
    addra = 16'h0001;
    dina  = 1'b1;
    wea   = 1'b1;
    #10;              // Allow one clock edge on clka for write
    wea   = 1'b0;    // Deassert write enable
    dina  = 1'b0;
    // Now perform a read (assuming the read is synchronous).
    // Wait enough time (at least 2 clka cycles) to see the written data appear.
    #30;
    
    // ---------------------------------------------------------------------
    // Test 2: Basic Write and Read on Port B 
    // Write a '1' to address 16'hFFFE using port B and read it back.
    // ---------------------------------------------------------------------
    addrb = 16'hFFFE;
    dinb  = 1'b1;
    web   = 1'b1;
    #14;              // One clkb cycle
    web   = 1'b0;
    dinb  = 1'b0;
    // Wait 2 clkb cycles for read latency
    #30;
    
    // ---------------------------------------------------------------------
    // Test 3: Simultaneous Write on Port A and Read on Port B 
    // Write '1' to address 16'h00FF via port A while reading from the same address on port B.
    // This test examines cross-port interactions.
    // ---------------------------------------------------------------------
    addra = 16'h00FF;
    dina  = 1'b1;
    wea   = 1'b1;
    // On port B, set the address for a read
    addrb = 16'h00FF;
    web   = 1'b0;   // Ensure read mode
    #10;
    wea   = 1'b0;
    dina  = 1'b0;
    // Wait for both ports' latency periods to resolve the read data.
    #30;
    
    // ---------------------------------------------------------------------
    // Test 4: Simultaneous Read on Both Ports 
    // Preload memory at address 16'h0100 then perform a simultaneous read from both ports.
    // ---------------------------------------------------------------------
    // Preload: Write '1' to address 16'h0100 using port A.
    addra = 16'h0100;
    dina  = 1'b1;
    wea   = 1'b1;
    #10;
    wea   = 1'b0;
    dina  = 1'b0;
    #30;  // Wait for the write latency
    
    // Now read from both ports at address 16'h0100.
    addra = 16'h0100;
    addrb = 16'h0100;
    // Both ports in read mode (wea and web deasserted).
    #30;
    
    // ---------------------------------------------------------------------
    // Test 5: Simultaneous Write from Both Ports to the Same Address 
    // This examines the undefined or specific resolution behavior when both ports try to write.
    // ---------------------------------------------------------------------
    addra = 16'h0200;
    addrb = 16'h0200;
    // Choose different data: port A writes '0', port B writes '1'.
    dina  = 1'b0;
    dinb  = 1'b1;
    wea   = 1'b1;
    web   = 1'b1;
    #10;
    wea   = 1'b0;
    web   = 1'b0;
    dina  = 1'b0;
    dinb  = 1'b0;
    // Read back from port A (or port B) to see what data is stored.
    addra = 16'h0200;
    #30;
    
    // ---------------------------------------------------------------------
    // Test 6: Boundary Address Tests 
    // Write to the lowest address (0x0000) using port A and highest address (0xFFFF) using port B.
    // ---------------------------------------------------------------------
    // Lowest address on Port A
    addra = 16'h0000;
    dina  = 1'b1;
    wea   = 1'b1;
    #10;
    wea   = 1'b0;
    dina  = 1'b0;
    #30;
    
    // Highest address on Port B
    addrb = 16'hFFFF;
    dinb  = 1'b1;
    web   = 1'b1;
    #14;
    web   = 1'b0;
    dinb  = 1'b0;
    #30;
    
    // ---------------------------------------------------------------------
    // Test 7: No-Write Operation 
    // Toggle the address and data signals without asserting the write enable,
    // ensuring that no inadvertent write occurs.
    // ---------------------------------------------------------------------
    addra = 16'h1234;
    dina  = 1'b1;
    wea   = 1'b0;   // Write enable is low
    #10;
    // Optionally read back (if previous data existed, it should be unchanged)
    #30;
    
    // ---------------------------------------------------------------------
    // Test 8: Random/Overlapping Operations Sequence
    // Issue multiple writes on port A and follow with reads on port B.
    // This tests how the BRAM handles back-to-back transactions.
    // ---------------------------------------------------------------------
    // First write on Port A: Write '1' at 16'h0A00.
    addra = 16'h0A00;
    dina  = 1'b1;
    wea   = 1'b1;
    #10;
    wea   = 1'b0;
    dina  = 1'b0;
    
    // Second write on Port A: Write '0' at 16'h0A01.
    #10;
    addra = 16'h0A01;
    dina  = 1'b0;
    wea   = 1'b1;
    #10;
    wea   = 1'b0;
    
    // Read back these values from Port B in sequence.
    addrb = 16'h0A00;
    #30;
    addrb = 16'h0A01;
    #30;
    
    // End of simulation
    $finish;
  end

endmodule
