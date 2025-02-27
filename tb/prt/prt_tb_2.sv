`timescale 1ns/1ps
module PRT_tb;

  // Parameters
  parameter DATA_WIDTH = 8;
  parameter MEM_DEPTH  = 2000;
  parameter NUM_SLOTS  = 2;

  // Clock and Reset
  logic CLK;
  logic RST_N;

  // DUT Signals
  logic EN_start_writing_prt_entry;
  logic start_writing_prt_entry;
  logic RDY_start_writing_prt_entry;

  logic [DATA_WIDTH-1:0] write_prt_entry_data;
  logic EN_write_prt_entry;
  logic RDY_write_prt_entry;

  logic EN_finish_writing_prt_entry;
  logic RDY_finish_writing_prt_entry;

  logic invalidate_prt_entry_slot;
  logic EN_invalidate_prt_entry;
  logic RDY_invalidate_prt_entry;

  logic start_reading_prt_entry_slot;
  logic EN_start_reading_prt_entry;
  logic RDY_start_reading_prt_entry;

  logic EN_read_prt_entry;
  logic [DATA_WIDTH:0] read_prt_entry; // [DATA_WIDTH-1:0] = data; [DATA_WIDTH] = complete flag
  logic RDY_read_prt_entry;

  logic is_prt_slot_free;
  logic RDY_is_prt_slot_free;

  // Instantiate DUT
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

  // Clock Generation: 10ns period
  always #5 CLK = ~CLK;

  //----------------------------------------------------------------------------
  // Task: Start Writing a PRT Entry
  //----------------------------------------------------------------------------
  task automatic startWrite();
    begin
      $display("\n[Time %0t] Starting Write Operation...", $time);
      if (is_prt_slot_free) begin
         EN_start_writing_prt_entry = 1;
         #10;
         EN_start_writing_prt_entry = 0;
         #10;
         $display("[Time %0t] RDY_start_writing_prt_entry = %0b, Chosen Slot = %0d",
                  $time, RDY_start_writing_prt_entry, start_writing_prt_entry);
      end else begin
         $display("[Time %0t] ERROR: No free slot available for writing!", $time);
      end
    end
  endtask

  //----------------------------------------------------------------------------
  // Task: Write Data to the PRT Entry
  //----------------------------------------------------------------------------
  task automatic writeData(input int numWords);
    int i;
    begin
      for (i = 0; i < numWords; i = i + 1) begin
         write_prt_entry_data = i[DATA_WIDTH-1:0];
         EN_write_prt_entry = 1;
         #10;
         EN_write_prt_entry = 0;
         #10;
         $display("[Time %0t] Written data word %0d: %0d", $time, i, write_prt_entry_data);
      end
    end
  endtask

  //----------------------------------------------------------------------------
  // Task: Finish Writing the PRT Entry
  //----------------------------------------------------------------------------
  task automatic finishWrite();
    begin
      $display("[Time %0t] Finishing Write Operation...", $time);
      EN_finish_writing_prt_entry = 1;
      #10;
      EN_finish_writing_prt_entry = 0;
      #10;
      $display("[Time %0t] RDY_finish_writing_prt_entry = %0b", $time, RDY_finish_writing_prt_entry);
    end
  endtask

  //----------------------------------------------------------------------------
  // Task: Start Reading a PRT Entry from a given slot
  //----------------------------------------------------------------------------
  task automatic startRead(input logic slot);
    begin
      $display("\n[Time %0t] Starting Read Operation from slot %0d...", $time, slot);
      start_reading_prt_entry_slot = slot;
      EN_start_reading_prt_entry = 1;
      #10;
      EN_start_reading_prt_entry = 0;
      #10;
      $display("[Time %0t] RDY_start_reading_prt_entry = %0b", $time, RDY_start_reading_prt_entry);
    end
  endtask

  //----------------------------------------------------------------------------
  // Task: Read Data from the PRT Entry until the complete flag is set
  //----------------------------------------------------------------------------
  task automatic readData();
    reg complete;
    reg [DATA_WIDTH-1:0] data;
    begin
      $display("[Time %0t] Starting to Read Data...", $time);
      complete = 0;
      while (!complete) begin
         EN_read_prt_entry = 1;
         #10;
         EN_read_prt_entry = 0;
         #10;
         data = read_prt_entry[DATA_WIDTH-1:0];
         complete = read_prt_entry[DATA_WIDTH];
         $display("[Time %0t] Read Data: %0d, Complete flag: %0b", $time, data, complete);
      end
      $display("[Time %0t] Completed Reading Data.", $time);
    end
  endtask

  //----------------------------------------------------------------------------
  // Task: Invalidate a PRT Entry
  //----------------------------------------------------------------------------
  task automatic invalidateEntry(input logic slot);
    begin
      $display("\n[Time %0t] Invalidating slot %0d...", $time, slot);
      invalidate_prt_entry_slot = slot;
      EN_invalidate_prt_entry = 1;
      #10;
      EN_invalidate_prt_entry = 0;
      #10;
      $display("[Time %0t] RDY_invalidate_prt_entry = %0b", $time, RDY_invalidate_prt_entry);
    end
  endtask

  //----------------------------------------------------------------------------
  // Test Case 1: Basic Write-Read-Invalidate Sequence
  //----------------------------------------------------------------------------
  task automatic testCase1();
    begin
      $display("\n--- Test Case 1: Basic Write-Read-Invalidate Sequence ---");
      startWrite();
      writeData(5);         // Write 5 data words
      finishWrite();
      startRead(start_writing_prt_entry);
      readData();
      invalidateEntry(start_writing_prt_entry);
    end
  endtask

  //----------------------------------------------------------------------------
  // Test Case 2: Write 10 Words and Read
  //----------------------------------------------------------------------------
  task automatic testCase2();
    begin
      $display("\n--- Test Case 2: Write 10 Words and Read ---");
      startWrite();
      writeData(10);        // Write 10 data words
      finishWrite();
      startRead(start_writing_prt_entry);
      readData();
    end
  endtask

  //----------------------------------------------------------------------------
  // Test Case 3: Attempt to Start Writing When Both Slots Are Occupied
  //----------------------------------------------------------------------------
  task automatic testCase3();
    begin
      $display("\n--- Test Case 3: Both Slots Occupied, New Write Attempt ---");
      // Write to first slot
      startWrite();
      writeData(3);
      finishWrite();
      // Write to second slot
      startWrite();
      writeData(4);
      finishWrite();
      // Now both slots should be occupied
      if (!is_prt_slot_free)
         $display("[Time %0t] Expected: No free slot available.", $time);
      else
         $display("[Time %0t] ERROR: Unexpected free slot available.", $time);
    end
  endtask

  //----------------------------------------------------------------------------
  // Test Case 4: Read from Specific Slots (Slot 0 and Slot 1)
  //----------------------------------------------------------------------------
  task automatic testCase4();
    begin
      $display("\n--- Test Case 4: Read from Specific Slots ---");
      // Invalidate both slots first to start fresh
      invalidateEntry(0);
      invalidateEntry(1);
      // Write into slot 0
      startWrite();
      writeData(6);
      finishWrite();
      // Write into slot 1
      startWrite();
      writeData(7);
      finishWrite();
      // Read from slot 0
      startRead(0);
      readData();
      // Read from slot 1
      startRead(1);
      readData();
    end
  endtask

  //----------------------------------------------------------------------------
  // Test Case 5: Invalidate an Already Invalid Slot
  //----------------------------------------------------------------------------
  task automatic testCase5();
    begin
      $display("\n--- Test Case 5: Invalidate Already Invalid Slot ---");
      // Ensure slot 0 is invalid
      invalidateEntry(0);
      // Attempt to invalidate slot 0 again
      invalidateEntry(0);
    end
  endtask

  //----------------------------------------------------------------------------
  // Test Case 6: Rapid Successive Operations
  //----------------------------------------------------------------------------
  task automatic testCase6();
    begin
      $display("\n--- Test Case 6: Rapid Successive Operations ---");
      startWrite();
      writeData(3);
      finishWrite();
      #5;
      startWrite();
      writeData(2);
      finishWrite();
      #5;
      startRead(start_writing_prt_entry);
      readData();
      invalidateEntry(start_writing_prt_entry);
    end
  endtask

  //----------------------------------------------------------------------------
  // Test Case 7: Write Zero Words and Finish Writing
  //----------------------------------------------------------------------------
  task automatic testCase7();
    begin
      $display("\n--- Test Case 7: Write Zero Words and Finish ---");
      startWrite();
      // No data written
      finishWrite();
      startRead(start_writing_prt_entry);
      readData();
      invalidateEntry(start_writing_prt_entry);
    end
  endtask

  //----------------------------------------------------------------------------
  // Test Case 8: Attempt to Read Without Proper Read Start
  //----------------------------------------------------------------------------
  task automatic testCase8();
    begin
      $display("\n--- Test Case 8: Read Without Starting Read Operation ---");
      // Directly enable read without issuing start_reading_prt_entry
      EN_read_prt_entry = 1;
      #10;
      EN_read_prt_entry = 0;
      $display("[Time %0t] RDY_read_prt_entry = %0b, read_prt_entry = %0d",
               $time, RDY_read_prt_entry, read_prt_entry);
    end
  endtask

  //----------------------------------------------------------------------------
  // Main Test Sequence
  //----------------------------------------------------------------------------
  initial begin
    $display("\n=== Starting PRT Module Testbench ===\n");
    CLK = 0;
    RST_N = 0;
    // Initialize all enables
    EN_start_writing_prt_entry = 0;
    EN_write_prt_entry = 0;
    EN_finish_writing_prt_entry = 0;
    EN_start_reading_prt_entry = 0;
    EN_read_prt_entry = 0;
    EN_invalidate_prt_entry = 0;
    #15; // Wait a few clock cycles
    RST_N = 1;
    #10;
    
    testCase1();
    #20;
    testCase2();
    #20;
    testCase3();
    #20;
    testCase4();
    #20;
    testCase5();
    #20;
    testCase6();
    #20;
    testCase7();
    #20;
    testCase8();
    
    $display("\n=== PRT Module Testbench Completed at time %0t ===", $time);
    $finish;
  end

endmodule
