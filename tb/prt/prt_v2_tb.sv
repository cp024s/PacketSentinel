`timescale 1ns/1ps

module tb_prt;

  //====================================================================
  // Parameters (match the PRT instance)
  //====================================================================
  parameter DATA_WIDTH = 8;
  parameter MEM_DEPTH  = 1518;
  parameter NUM_SLOTS  = 2;

  //====================================================================
  // Clock & Reset
  //====================================================================
  logic clk;
  logic rst_n;
  
  initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 10 ns period
  end

  initial begin
    rst_n = 0;
    #20; // Hold reset low for 20 ns
    rst_n = 1;
  end
  
  //====================================================================
  // Interface Signals for PRT Transactions
  //====================================================================
  // Write signals
  logic                          EN_start_writing_prt_entry;
  logic [$clog2(NUM_SLOTS)-1:0]  start_writing_prt_entry;
  logic                          RDY_start_writing_prt_entry;
  
  logic [DATA_WIDTH-1:0]         write_prt_entry_data;
  logic                          EN_write_prt_entry;
  logic                          RDY_write_prt_entry;
  
  logic                          EN_finish_writing_prt_entry;
  logic                          RDY_finish_writing_prt_entry;
  
  // Invalidate signals
  logic [$clog2(NUM_SLOTS)-1:0]  invalidate_prt_entry_slot;
  logic                          EN_invalidate_prt_entry;
  logic                          RDY_invalidate_prt_entry;
  
  // Read signals
  logic [$clog2(NUM_SLOTS)-1:0]  start_reading_prt_entry_slot;
  logic                          EN_start_reading_prt_entry;
  logic                          RDY_start_reading_prt_entry;
  
  logic                          EN_read_prt_entry;
  logic [DATA_WIDTH:0]           read_prt_entry;
  logic                          RDY_read_prt_entry;
  
  // Free slot status
  logic                          is_prt_slot_free;
  logic                          RDY_is_prt_slot_free;
  
  //====================================================================
  // Instantiate the PRT module
  //====================================================================
  PRT_v2 #(
    .DATA_WIDTH(DATA_WIDTH),
    .MEM_DEPTH(MEM_DEPTH),
    .NUM_SLOTS(NUM_SLOTS)
  ) prt_inst (
    .CLK(clk),
    .RST_N(rst_n),
    // Write transaction
    .EN_start_writing_prt_entry(EN_start_writing_prt_entry),
    .start_writing_prt_entry(start_writing_prt_entry),
    .RDY_start_writing_prt_entry(RDY_start_writing_prt_entry),
    .write_prt_entry_data(write_prt_entry_data),
    .EN_write_prt_entry(EN_write_prt_entry),
    .RDY_write_prt_entry(RDY_write_prt_entry),
    .EN_finish_writing_prt_entry(EN_finish_writing_prt_entry),
    .RDY_finish_writing_prt_entry(RDY_finish_writing_prt_entry),
    // Invalidate transaction
    .invalidate_prt_entry_slot(invalidate_prt_entry_slot),
    .EN_invalidate_prt_entry(EN_invalidate_prt_entry),
    .RDY_invalidate_prt_entry(RDY_invalidate_prt_entry),
    // Read transaction
    .start_reading_prt_entry_slot(start_reading_prt_entry_slot),
    .EN_start_reading_prt_entry(EN_start_reading_prt_entry),
    .RDY_start_reading_prt_entry(RDY_start_reading_prt_entry),
    .EN_read_prt_entry(EN_read_prt_entry),
    .read_prt_entry(read_prt_entry),
    .RDY_read_prt_entry(RDY_read_prt_entry),
    // Free slot check
    .is_prt_slot_free(is_prt_slot_free),
    .RDY_is_prt_slot_free(RDY_is_prt_slot_free)
  );

  //====================================================================
  // Transaction Tasks
  //====================================================================
  
  // Task: Write a frame of given length with sequential data starting from 'start_value'
  task automatic write_frame(input int frame_length, input logic [7:0] start_value);
    int i;
    begin
      $display("\n[Test Write] Starting write transaction for frame_length = %0d at time %t", frame_length, $time);
      // Step 1: Request to start write
      @(posedge clk);
      EN_start_writing_prt_entry = 1;
      @(posedge clk);
      EN_start_writing_prt_entry = 0;
      
      // Wait until a ready pulse acknowledges S_WRITE_START
      while(!RDY_start_writing_prt_entry) @(posedge clk);
      $display("[Test Write] Write Start acknowledged. Slot chosen = %0d at time %t", start_writing_prt_entry, $time);
      
      // Step 2: Write frame data byte-by-byte
      for(i = 0; i < frame_length; i = i + 1) begin
        @(posedge clk);
        EN_write_prt_entry = 1;
        write_prt_entry_data = start_value + i;
      end
      @(posedge clk);
      EN_write_prt_entry = 0;
      
      // Step 3: Finish writing
      @(posedge clk);
      EN_finish_writing_prt_entry = 1;
      @(posedge clk);
      EN_finish_writing_prt_entry = 0;
      while(!RDY_finish_writing_prt_entry) @(posedge clk);
      $display("[Test Write] Write Finish acknowledged at time %t", $time);
    end
  endtask
  
  // Task: Read a frame. It will read for "expected_length" cycles plus extra cycles to capture the complete flag.
  task automatic read_frame(input int expected_length);
    int i;
    logic complete;
    logic [7:0] data;
    begin
      $display("\n[Test Read] Starting read transaction for expected_length = %0d at time %t", expected_length, $time);
      // Step 1: Request to start read. We assume the last written slot is to be read.
      @(posedge clk);
      start_reading_prt_entry_slot = start_writing_prt_entry; // Read from the slot that was just written
      EN_start_reading_prt_entry = 1;
      @(posedge clk);
      EN_start_reading_prt_entry = 0;
      while(!RDY_start_reading_prt_entry) @(posedge clk);
      $display("[Test Read] Read Start acknowledged at time %t", $time);
      
      // Step 2: Read data bytes until the complete flag is observed.
      for(i = 0; i < expected_length + 3; i = i + 1) begin
        @(posedge clk);
        EN_read_prt_entry = 1;
        @(posedge clk);
        EN_read_prt_entry = 0;
        data = read_prt_entry[DATA_WIDTH-1:0];
        complete = read_prt_entry[DATA_WIDTH];
        $display("[Test Read] Time %t: Data = 0x%0h, Complete = %b", $time, data, complete);
      end
    end
  endtask
  
  // Task: Invalidate a given slot.
  task automatic invalidate_slot(input logic [$clog2(NUM_SLOTS)-1:0] slot);
    begin
      $display("\n[Test Invalidate] Request to invalidate slot %0d at time %t", slot, $time);
      @(posedge clk);
      invalidate_prt_entry_slot = slot;
      EN_invalidate_prt_entry = 1;
      @(posedge clk);
      EN_invalidate_prt_entry = 0;
      while(!RDY_invalidate_prt_entry) @(posedge clk);
      $display("[Test Invalidate] Invalidation acknowledged for slot %0d at time %t", slot, $time);
    end
  endtask
  
  // Task: Partial Read - perform a read for a few bytes, then stop, then resume.
  task automatic partial_read(input int part1, input int part2);
    int i;
    logic complete;
    logic [7:0] data;
    begin
      $display("\n[Test Partial Read] Starting partial read: first %0d bytes then later %0d bytes, at time %t", part1, part2, $time);
      // Initiate read transaction from last written slot.
      @(posedge clk);
      start_reading_prt_entry_slot = start_writing_prt_entry;
      EN_start_reading_prt_entry = 1;
      @(posedge clk);
      EN_start_reading_prt_entry = 0;
      while(!RDY_start_reading_prt_entry) @(posedge clk);
      
      // Part 1: Read first part1 bytes
      for(i = 0; i < part1; i = i + 1) begin
        @(posedge clk);
        EN_read_prt_entry = 1;
        @(posedge clk);
        EN_read_prt_entry = 0;
        data = read_prt_entry[DATA_WIDTH-1:0];
        complete = read_prt_entry[DATA_WIDTH];
        $display("[Partial Read] Time %t: Byte %0d = 0x%0h, Complete = %b", $time, i, data, complete);
      end
      
      // Simulate pause in reading
      $display("[Partial Read] Pausing read for a few cycles at time %t", $time);
      repeat(5) @(posedge clk);
      
      // Part 2: Resume reading remaining bytes
      for(i = part1; i < part1 + part2; i = i + 1) begin
        @(posedge clk);
        EN_read_prt_entry = 1;
        @(posedge clk);
        EN_read_prt_entry = 0;
        data = read_prt_entry[DATA_WIDTH-1:0];
        complete = read_prt_entry[DATA_WIDTH];
        $display("[Partial Read] Time %t: Byte %0d = 0x%0h, Complete = %b", $time, i, data, complete);
      end
    end
  endtask
  
  //====================================================================
  // Testbench Main Sequence: Covering all edge and corner cases
  //====================================================================
  initial begin
    // Initialize all enables and input signals to 0.
    EN_start_writing_prt_entry = 0;
    EN_write_prt_entry         = 0;
    EN_finish_writing_prt_entry= 0;
    EN_invalidate_prt_entry    = 0;
    EN_start_reading_prt_entry = 0;
    EN_read_prt_entry          = 0;
    start_reading_prt_entry_slot = 0;
    
    // Wait until reset is released.
    @(posedge rst_n);
    repeat (2) @(posedge clk);
    
    //-------------------------------------------------------------
    // Test Case 1: Write a 10-byte frame into an empty slot.
    //-------------------------------------------------------------
    $display("\n*** Test Case 1: Write a 10-byte frame into an empty slot ***");
    write_frame(10, 8'hA0);
    
    //-------------------------------------------------------------
    // Test Case 2: Read the 10-byte frame just written.
    //-------------------------------------------------------------
    $display("\n*** Test Case 2: Read the 10-byte frame ***");
    read_frame(10);
    
    //-------------------------------------------------------------
    // Test Case 3: Invalidate the slot that was just used.
    //-------------------------------------------------------------
    $display("\n*** Test Case 3: Invalidate the previously written slot ***");
    invalidate_slot(start_writing_prt_entry);
    
    //-------------------------------------------------------------
    // Test Case 4: Write two frames sequentially to fill both slots.
    //-------------------------------------------------------------
    $display("\n*** Test Case 4: Write two frames sequentially (fill both slots) ***");
    write_frame(5, 8'h10);  // Frame 1 (slot 0)
    write_frame(7, 8'h20);  // Frame 2 (slot 1)
    
    //-------------------------------------------------------------
    // Test Case 5: Attempt to write when no free slot is available.
    //-------------------------------------------------------------
    $display("\n*** Test Case 5: Attempt write when no free slot is available ***");
    if(!is_prt_slot_free)
      $display("[Edge Case] No free slot available as expected at time %t", $time);
    else
      $display("[Edge Case] Unexpected free slot at time %t", $time);
      
    // Try to start a write transaction (this should not produce a ready pulse).
    @(posedge clk);
    EN_start_writing_prt_entry = 1;
    @(posedge clk);
    EN_start_writing_prt_entry = 0;
    @(posedge clk);
    if(RDY_start_writing_prt_entry)
      $display("[Edge Case] Error: Write start ready pulse received when no free slot expected at time %t", $time);
    else
      $display("[Edge Case] Correctly, no ready pulse received for write start at time %t", $time);
      
    //-------------------------------------------------------------
    // Test Case 6: Attempt to read from an invalid slot.
    //-------------------------------------------------------------
    $display("\n*** Test Case 6: Attempt read from an invalid slot ***");
    // Invalidate slot 0 explicitly.
    invalidate_slot(0);
    @(posedge clk);
    start_reading_prt_entry_slot = 0;  // Attempt to read from slot 0, which is now invalid.
    EN_start_reading_prt_entry = 1;
    @(posedge clk);
    EN_start_reading_prt_entry = 0;
    @(posedge clk);
    if(RDY_start_reading_prt_entry)
      $display("[Edge Case] Error: Read start ready pulse received for invalid slot 0 at time %t", $time);
    else
      $display("[Edge Case] Correctly, no read start ready pulse for invalid slot 0 at time %t", $time);
      
    //-------------------------------------------------------------
    // Test Case 7: Write a minimal frame (1 byte) and then read it.
    //-------------------------------------------------------------
    $display("\n*** Test Case 7: Write a minimal 1-byte frame and read it ***");
    write_frame(1, 8'h55);
    read_frame(1);
    
    //-------------------------------------------------------------
    // Test Case 8: Write a maximum-length frame (MEM_DEPTH bytes).
    //-------------------------------------------------------------
    $display("\n*** Test Case 8: Write a maximum-length frame (%0d bytes) ***", MEM_DEPTH);
    write_frame(MEM_DEPTH, 8'h00);
    read_frame(MEM_DEPTH);
    
    //-------------------------------------------------------------
    // Test Case 9: Partial read test - read part of a frame, pause, and resume.
    //-------------------------------------------------------------
    $display("\n*** Test Case 9: Partial read test ***");
    // Write a 20-byte frame.
    write_frame(20, 8'hC0);
    // Now do a partial read: first 10 bytes, pause, then read the remaining 10 bytes.
    partial_read(10, 10);
    
    //-------------------------------------------------------------
    // Test Case 10: Invalidate an already invalid (empty) slot.
    //-------------------------------------------------------------
    $display("\n*** Test Case 10: Invalidate an already invalid slot ***");
    // Assume slot 0 is already invalid from Test Case 6.
    invalidate_slot(0);
    
    //-------------------------------------------------------------
    // Test Case 11: Sequential operations on the same slot.
    // Write a frame, read part of it, then invalidate, and finally write a new frame into that slot.
    //-------------------------------------------------------------
    $display("\n*** Test Case 11: Sequential operations on one slot ***");
    write_frame(8, 8'hD0);
    partial_read(4, 0);  // Read 4 bytes then stop (simulate interruption)
    invalidate_slot(start_writing_prt_entry); // Invalidate the slot that was just partially read.
    write_frame(6, 8'hE0);  // Write new frame into the now free slot.
    read_frame(6);
    
    //-------------------------------------------------------------
    // End of Testbench
    //-------------------------------------------------------------
    #200;
    $display("\n*** Testbench completed at time %t ***", $time);
    $finish;
  end

endmodule
