`timescale 1ns / 1ps

module PRT_tb;

  // Parameters (match those of your design)
  parameter DATA_WIDTH = 8;
  parameter MEM_DEPTH  = 2000;
  parameter NUM_SLOTS  = 2;

  // Clock and Reset signals
  logic CLK;
  logic RST_N;

  // DUT I/O signals
  logic                   EN_start_writing_prt_entry;
  logic                   start_writing_prt_entry; // Chosen slot output (0 or 1)
  logic                   RDY_start_writing_prt_entry;

  logic [DATA_WIDTH-1:0]  write_prt_entry_data;
  logic                   EN_write_prt_entry;
  logic                   RDY_write_prt_entry;
  
  logic                   EN_finish_writing_prt_entry;
  logic                   RDY_finish_writing_prt_entry;

  logic                   invalidate_prt_entry_slot; // Which slot to invalidate (0 or 1)
  logic                   EN_invalidate_prt_entry;
  logic                   RDY_invalidate_prt_entry;

  logic                   start_reading_prt_entry_slot; // Which slot to read from (0 or 1)
  logic                   EN_start_reading_prt_entry;
  logic                   RDY_start_reading_prt_entry;

  logic                   EN_read_prt_entry;
  logic [DATA_WIDTH:0]    read_prt_entry; // [DATA_WIDTH-1:0] data, bit DATA_WIDTH is completion flag
  logic                   RDY_read_prt_entry;

  logic                   is_prt_slot_free;
  logic                   RDY_is_prt_slot_free;

  // Instantiate the DUT
  PRT #(DATA_WIDTH, MEM_DEPTH, NUM_SLOTS) dut (
    .CLK(CLK),
    .RST_N(RST_N),
    .EN_start_writing_prt_entry(EN_start_writing_prt_entry),
    .start_writing_prt_entry(start_writing_prt_entry),
    .RDY_start_writing_prt_entry(RDY_start_writing_prt_entry),
    .write_prt_entry_data(write_prt_entry_data),
    .EN_write_prt_entry(EN_write_prt_entry),
    .RDY_write_prt_entry(RDY_write_prt_entry),
    .EN_finish_writing_prt_entry(EN_finish_writing_prt_entry),
    .RDY_finish_writing_prt_entry(RDY_finish_writing_prt_entry),
    .invalidate_prt_entry_slot(invalidate_prt_entry_slot),
    .EN_invalidate_prt_entry(EN_invalidate_prt_entry),
    .RDY_invalidate_prt_entry(RDY_invalidate_prt_entry),
    .start_reading_prt_entry_slot(start_reading_prt_entry_slot),
    .EN_start_reading_prt_entry(EN_start_reading_prt_entry),
    .RDY_start_reading_prt_entry(RDY_start_reading_prt_entry),
    .EN_read_prt_entry(EN_read_prt_entry),
    .read_prt_entry(read_prt_entry),
    .RDY_read_prt_entry(RDY_read_prt_entry),
    .is_prt_slot_free(is_prt_slot_free),
    .RDY_is_prt_slot_free(RDY_is_prt_slot_free)
  );

  // Clock generation: 10ns period
  always #5 CLK = ~CLK;

  // Testbench procedure with multiple testcases
  initial begin
    // Initialization and Reset
    CLK = 0;
    RST_N = 0;
    EN_start_writing_prt_entry = 0;
    EN_write_prt_entry = 0;
    EN_finish_writing_prt_entry = 0;
    EN_invalidate_prt_entry = 0;
    EN_start_reading_prt_entry = 0;
    EN_read_prt_entry = 0;
    write_prt_entry_data = '0;
    invalidate_prt_entry_slot = 0;
    start_reading_prt_entry_slot = 0;
    
    $display("== Testbench Started ==");
    #15; 
    RST_N = 1; // Release reset
    #10;

    //===================================================
    // Test Case 1: Normal Write-Read-Invalidate Sequence
    //===================================================
    $display("\n-- Test Case 1: Normal Write-Read-Invalidate --");
    if (is_prt_slot_free) begin
      // Start Writing a new entry
      $display("Starting write operation (should be free)...");
      EN_start_writing_prt_entry = 1;
      #10;
      EN_start_writing_prt_entry = 0;
      #10;  // wait one cycle
      
      // Write Data: write 5 data words (0 to 4)
      $display("Writing data words 0 to 4");
      for (int i = 0; i < 5; i++) begin
        write_prt_entry_data = i;
        EN_write_prt_entry = 1;
        #10;
        EN_write_prt_entry = 0;
        #5;
      end

      // Finish Writing
      $display("Finishing write operation.");
      EN_finish_writing_prt_entry = 1;
      #10;
      EN_finish_writing_prt_entry = 0;
      #10;
      
      // Start Reading from the same slot
      $display("Starting read operation from slot %0d", start_writing_prt_entry);
      start_reading_prt_entry_slot = start_writing_prt_entry; 
      EN_start_reading_prt_entry = 1;
      #10;
      EN_start_reading_prt_entry = 0;
      #10;
      
      // Read Data until completion flag is high
      $display("Reading data...");
      while (1) begin
        EN_read_prt_entry = 1;
        #10;
        EN_read_prt_entry = 0;
        #5;
        $display("Read data: %0d, complete flag: %b", read_prt_entry[DATA_WIDTH-1:0], read_prt_entry[DATA_WIDTH]);
        if (read_prt_entry[DATA_WIDTH] == 1)
          break;
      end
      #10;
      
      // Invalidate the entry
      $display("Invalidating slot %0d", start_writing_prt_entry);
      invalidate_prt_entry_slot = start_writing_prt_entry;
      EN_invalidate_prt_entry = 1;
      #10;
      EN_invalidate_prt_entry = 0;
      #10;
    end

    //===================================================
    // Test Case 2: Zero-Data Write (finish immediately)
    //===================================================
    $display("\n-- Test Case 2: Zero-Data Write --");
    if (is_prt_slot_free) begin
      EN_start_writing_prt_entry = 1;
      #10;
      EN_start_writing_prt_entry = 0;
      #10;
      // Immediately finish without any write operations
      EN_finish_writing_prt_entry = 1;
      #10;
      EN_finish_writing_prt_entry = 0;
      #10;
      
      // Start reading; since no data was written, complete flag should be immediately high.
      start_reading_prt_entry_slot = start_writing_prt_entry;
      EN_start_reading_prt_entry = 1;
      #10;
      EN_start_reading_prt_entry = 0;
      #10;
      
      EN_read_prt_entry = 1;
      #10;
      EN_read_prt_entry = 0;
      $display("Zero-data entry read: Data = %0d, complete flag = %b", read_prt_entry[DATA_WIDTH-1:0], read_prt_entry[DATA_WIDTH]);
      #10;
      
      // Invalidate the entry
      invalidate_prt_entry_slot = start_writing_prt_entry;
      EN_invalidate_prt_entry = 1;
      #10;
      EN_invalidate_prt_entry = 0;
      #10;
    end

    //===================================================
    // Test Case 3: Two Consecutive Entries (Different Slots)
    //===================================================
    $display("\n-- Test Case 3: Two Consecutive Entries --");
    // Write first entry
    if (is_prt_slot_free) begin
      $display("Writing first entry (data 10-14)...");
      EN_start_writing_prt_entry = 1;
      #10;
      EN_start_writing_prt_entry = 0;
      #10;
      for (int i = 10; i < 15; i++) begin
        write_prt_entry_data = i;
        EN_write_prt_entry = 1;
        #10;
        EN_write_prt_entry = 0;
        #5;
      end
      EN_finish_writing_prt_entry = 1;
      #10;
      EN_finish_writing_prt_entry = 0;
      #10;
    end
    // Write second entry
    if (is_prt_slot_free) begin
      $display("Writing second entry (data 20-24)...");
      EN_start_writing_prt_entry = 1;
      #10;
      EN_start_writing_prt_entry = 0;
      #10;
      for (int i = 20; i < 25; i++) begin
        write_prt_entry_data = i;
        EN_write_prt_entry = 1;
        #10;
        EN_write_prt_entry = 0;
        #5;
      end
      EN_finish_writing_prt_entry = 1;
      #10;
      EN_finish_writing_prt_entry = 0;
      #10;
    end
    
    // Read first entry (assumed in slot 0)
    $display("Reading first entry (slot 0)...");
    start_reading_prt_entry_slot = 0;
    EN_start_reading_prt_entry = 1;
    #10;
    EN_start_reading_prt_entry = 0;
    #10;
    while (1) begin
      EN_read_prt_entry = 1;
      #10;
      EN_read_prt_entry = 0;
      #5;
      if (read_prt_entry[DATA_WIDTH] == 1) begin
        $display("Finished reading first entry.");
        break;
      end
    end
    #10;
    
    // Read second entry (assumed in slot 1)
    $display("Reading second entry (slot 1)...");
    start_reading_prt_entry_slot = 1;
    EN_start_reading_prt_entry = 1;
    #10;
    EN_start_reading_prt_entry = 0;
    #10;
    while (1) begin
      EN_read_prt_entry = 1;
      #10;
      EN_read_prt_entry = 0;
      #5;
      if (read_prt_entry[DATA_WIDTH] == 1) begin
        $display("Finished reading second entry.");
        break;
      end
    end
    #10;
    
    // Invalidate both entries
    $display("Invalidating both entries...");
    invalidate_prt_entry_slot = 0;
    EN_invalidate_prt_entry = 1;
    #10;
    EN_invalidate_prt_entry = 0;
    #10;
    invalidate_prt_entry_slot = 1;
    EN_invalidate_prt_entry = 1;
    #10;
    EN_invalidate_prt_entry = 0;
    #10;
    
    //===================================================
    // Test Case 4: Attempt Write When No Slot is Free
    //===================================================
    $display("\n-- Test Case 4: Write Attempt with No Free Slot --");
    // First, fill both slots.
    // Write to slot 0 if free.
    if (is_prt_slot_free) begin
      $display("Filling slot 0 with data 30-34...");
      EN_start_writing_prt_entry = 1;
      #10; EN_start_writing_prt_entry = 0; #10;
      for (int i = 30; i < 35; i++) begin
        write_prt_entry_data = i;
        EN_write_prt_entry = 1; #10; EN_write_prt_entry = 0; #5;
      end
      EN_finish_writing_prt_entry = 1; #10; EN_finish_writing_prt_entry = 0; #10;
    end
    // Write to slot 1 if free.
    if (is_prt_slot_free) begin
      $display("Filling slot 1 with data 40-44...");
      EN_start_writing_prt_entry = 1;
      #10; EN_start_writing_prt_entry = 0; #10;
      for (int i = 40; i < 45; i++) begin
        write_prt_entry_data = i;
        EN_write_prt_entry = 1; #10; EN_write_prt_entry = 0; #5;
      end
      EN_finish_writing_prt_entry = 1; #10; EN_finish_writing_prt_entry = 0; #10;
    end
    // Both slots now should be full.
    if (!is_prt_slot_free) begin
      $display("No free slot available as expected.");
      // Try to start a write; RDY_start_writing_prt_entry should not be high.
      EN_start_writing_prt_entry = 1;
      #10;
      if (RDY_start_writing_prt_entry)
        $display("Error: Unexpected readiness when no slot is free!");
      else
        $display("Correct: Not ready to write when no slot is free.");
      EN_start_writing_prt_entry = 0;
      #10;
    end
    // Free up a slot
    $display("Freeing up slot 0 by invalidation.");
    invalidate_prt_entry_slot = 0;
    EN_invalidate_prt_entry = 1;
    #10; EN_invalidate_prt_entry = 0; #10;
    
    //===================================================
    // Test Case 5: Attempt to Read from an Invalid Entry
    //===================================================
    $display("\n-- Test Case 5: Read from Invalid Entry --");
    // Try to start reading from slot 0 (which was just invalidated)
    start_reading_prt_entry_slot = 0;
    EN_start_reading_prt_entry = 1;
    #10;
    EN_start_reading_prt_entry = 0;
    #10;
    if (!RDY_start_reading_prt_entry)
      $display("Correct: Not ready to read from an invalid entry.");
    else
      $display("Error: Unexpected readiness to read an invalid entry.");
    #10;
    
    //===================================================
    // Test Case 6: Reset Mid-Operation
    //===================================================
    $display("\n-- Test Case 6: Reset During Operation --");
    if (is_prt_slot_free) begin
      // Start a new write
      EN_start_writing_prt_entry = 1; #10; EN_start_writing_prt_entry = 0; #10;
      // Write one data word
      write_prt_entry_data = 100;
      EN_write_prt_entry = 1; #10; EN_write_prt_entry = 0; #10;
      // Assert reset in the middle of the operation
      $display("Asserting reset mid-operation.");
      RST_N = 0; #15; RST_N = 1; #10;
      // Attempt to finish write after reset
      EN_finish_writing_prt_entry = 1; #10; EN_finish_writing_prt_entry = 0; #10;
    end
    
    //===================================================
    // Test Case 7: High Volume Data Write (Partial Simulation)
    //===================================================
    $display("\n-- Test Case 7: High Volume Data Write --");
    if (is_prt_slot_free) begin
      EN_start_writing_prt_entry = 1; #10; EN_start_writing_prt_entry = 0; #10;
      // For simulation, write 20 words (instead of MEM_DEPTH) with data starting at 200
      for (int i = 0; i < 20; i++) begin
        write_prt_entry_data = i + 200;
        EN_write_prt_entry = 1; #10; EN_write_prt_entry = 0; #5;
      end
      EN_finish_writing_prt_entry = 1; #10; EN_finish_writing_prt_entry = 0; #10;
      
      // Start reading the high volume entry
      start_reading_prt_entry_slot = start_writing_prt_entry;
      EN_start_reading_prt_entry = 1; #10; EN_start_reading_prt_entry = 0; #10;
      while (1) begin
        EN_read_prt_entry = 1; #10; EN_read_prt_entry = 0; #5;
        if (read_prt_entry[DATA_WIDTH] == 1) begin
          $display("Completed reading high volume entry.");
          break;
        end
      end
      #10;
    end

    $display("\n== All Test Cases Completed ==");
    $stop;
  end

endmodule
