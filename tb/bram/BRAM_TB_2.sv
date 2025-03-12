`timescale 1ns/1ps
module tb_PRT;

  // Clock and signal declarations
  reg         clka, clkb;
  reg         wea;
  reg  [15:0] addra, addrb;
  reg         dina;
  wire        doutb;

  // Instantiate the BRAM IP
  PRT PRT_inst (
    .clka(clka),
    .wea(wea),
    .addra(addra),
    .dina(dina),
    .douta(), // Unused as we don't read from port A
    .clkb(clkb),
    .web(1'b0), // Port B is read-only, so no write enable
    .addrb(addrb),
    .dinb(1'b0), // Unused as we don't write to port B
    .doutb(doutb)
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

  // Monitor key signals during simulation
  initial begin
    $monitor("Time=%0t | clka=%b addra=%h wea=%b dina=%b || clkb=%b addrb=%h doutb=%b",
             $time, clka, addra, wea, dina, clkb, addrb, doutb);
  end

  // Stimulus
  initial begin
    // Initialize signals
    wea   = 1'b0;
    addra = 16'h0000;
    addrb = 16'h0000;
    dina  = 1'b0;
    
    #20;

    // Test 1: Basic Write on Port A and Read from Port B
    $display("Test 1: Basic Write on Port A and Read from Port B");
    addra = 16'h0001;
    dina  = 1'b1;
    wea   = 1'b1;
    #10;
    wea   = 1'b0;
    dina  = 1'b0;
    #30;
    addrb = 16'h0001; // Read after required latency
    #30;

    // Test 2: Writing to Multiple Locations and Reading
    $display("Test 2: Writing to Multiple Locations and Reading");
    addra = 16'h00A0;
    dina  = 1'b1;
    wea   = 1'b1;
    #10;
    wea   = 1'b0;
    dina  = 1'b0;
    #30;
    addra = 16'h00B0;
    dina  = 1'b0;
    wea   = 1'b1;
    #10;
    wea   = 1'b0;
    #30;
    addrb = 16'h00A0;
    #30;
    addrb = 16'h00B0;
    #30;

    // Test 3: Edge Case - Writing to Address 0x0000 and Reading
    $display("Test 3: Edge Case - Writing to Address 0x0000 and Reading");
    addra = 16'h0000;
    dina  = 1'b1;
    wea   = 1'b1;
    #10;
    wea   = 1'b0;
    dina  = 1'b0;
    #30;
    addrb = 16'h0000;
    #30;

    // Test 4: Edge Case - Writing to the Last Address 0xFFFF
    $display("Test 4: Edge Case - Writing to the Last Address 0xFFFF");
    addra = 16'hFFFF;
    dina  = 1'b1;
    wea   = 1'b1;
    #10;
    wea   = 1'b0;
    dina  = 1'b0;
    #30;
    addrb = 16'hFFFF;
    #30;

    // Test 5: Writing Alternating Data Patterns
    $display("Test 5: Writing Alternating Data Patterns");
    addra = 16'h0100;
    dina  = 1'b0;
    wea   = 1'b1;
    #10;
    wea   = 1'b0;
    dina  = 1'b1;
    addra = 16'h0101;
    wea   = 1'b1;
    #10;
    wea   = 1'b0;
    #30;
    addrb = 16'h0100;
    #30;
    addrb = 16'h0101;
    #30;

    // Test 6: Random Address Read-After-Write
    $display("Test 6: Random Address Read-After-Write");
    addra = 16'h0F0F;
    dina  = 1'b1;
    wea   = 1'b1;
    #10;
    wea   = 1'b0;
    dina  = 1'b0;
    #30;
    addrb = 16'h0F0F;
    #30;

    // End of simulation
    $display("Testbench completed.");
    $finish;
  end

endmodule
