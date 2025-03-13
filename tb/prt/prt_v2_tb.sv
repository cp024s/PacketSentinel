`timescale 1ns/1ps

module PRT_tb;

  // Testbench Parameters
  parameter DATA_WIDTH = 8;
  parameter MEM_DEPTH = 1518;
  parameter NUM_SLOTS = 2;
  parameter CLK_PERIOD = 10;

  // DUT Interface Signals
  logic CLK;
  logic RST_N;

  // Write Transaction Signals
  logic EN_start_writing_prt_entry;
  logic [$clog2(NUM_SLOTS)-1:0] start_writing_prt_entry;
  logic RDY_start_writing_prt_entry;
  
  logic [DATA_WIDTH-1:0] write_prt_entry_data;
  logic EN_write_prt_entry;
  logic RDY_write_prt_entry;

  logic EN_finish_writing_prt_entry;
  logic RDY_finish_writing_prt_entry;

  // Invalidate Transaction Signals
  logic [$clog2(NUM_SLOTS)-1:0] invalidate_prt_entry_slot;
  logic EN_invalidate_prt_entry;
  logic RDY_invalidate_prt_entry;

  // Read Transaction Signals
  logic [$clog2(NUM_SLOTS)-1:0] start_reading_prt_entry_slot;
  logic EN_start_reading_prt_entry;
  logic RDY_start_reading_prt_entry;

  logic EN_read_prt_entry;
  logic [DATA_WIDTH:0] read_prt_entry;
  logic RDY_read_prt_entry;

  // Free Slot Check
  logic is_prt_slot_free;
  logic RDY_is_prt_slot_free;

  // Variable for slot selection
  int allocated_slot;  // 🔧 FIX: Declare at the top, before the `initial` block.

  // Instantiate the DUT (PRT Module)
  PRT dut (
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

  // Clock Generation
  always #(CLK_PERIOD / 2) CLK = ~CLK;

  // Test Procedure
  initial begin
    $display("==== Starting PRT Testbench ====");
    CLK = 0;
    RST_N = 0;
    EN_start_writing_prt_entry = 0;
    EN_write_prt_entry = 0;
    EN_finish_writing_prt_entry = 0;
    EN_start_reading_prt_entry = 0;
    EN_read_prt_entry = 0;
    EN_invalidate_prt_entry = 0;
    
    // Reset Sequence
    $display("Resetting the PRT...");
    #20 RST_N = 1;
    #10;
    
    // 1️⃣ Test Writing a Frame
    $display("Starting Write Test...");
    EN_start_writing_prt_entry = 1;
    wait (RDY_start_writing_prt_entry);
    EN_start_writing_prt_entry = 0;
    #10;
    
    // Store allocated slot
    allocated_slot = start_writing_prt_entry;  // ✅ FIXED: Declare before `initial`
    $display("Writing to Slot %0d", allocated_slot);
    
    for (int i = 0; i < 10; i++) begin
      write_prt_entry_data = i;
      EN_write_prt_entry = 1;
      wait (RDY_write_prt_entry);
      #10;
    end
    EN_write_prt_entry = 0;
    #10;

    // Finish Write
    EN_finish_writing_prt_entry = 1;
    wait (RDY_finish_writing_prt_entry);
    EN_finish_writing_prt_entry = 0;
    $display("Write Transaction Completed");

    // 2️⃣ Test Reading from PRT
    $display("Starting Read Test...");
    EN_start_reading_prt_entry = 1;
    start_reading_prt_entry_slot = allocated_slot;
    wait (RDY_start_reading_prt_entry);
    EN_start_reading_prt_entry = 0;
    #10;

    for (int i = 0; i < 10; i++) begin
      EN_read_prt_entry = 1;
      wait (RDY_read_prt_entry);
      $display("Read Data: %0d", read_prt_entry[DATA_WIDTH-1:0]);
      #10;
    end
    EN_read_prt_entry = 0;
    $display("Read Transaction Completed");

    // 3️⃣ Test Invalidating a Slot
    $display("Invalidating Slot %0d", allocated_slot);
    invalidate_prt_entry_slot = allocated_slot;
    EN_invalidate_prt_entry = 1;
    wait (RDY_invalidate_prt_entry);
    EN_invalidate_prt_entry = 0;
    $display("Invalidation Completed");

    // 4️⃣ Edge Case: Read from Invalid Slot
    $display("Attempting to Read from Invalid Slot %0d", allocated_slot);
    EN_start_reading_prt_entry = 1;
    start_reading_prt_entry_slot = allocated_slot;
    #10;
    EN_start_reading_prt_entry = 0;
    
    if (!RDY_start_reading_prt_entry)
      $display("Correctly detected invalid slot!");

    $display("==== Testbench Completed ====");
    $finish;
  end

endmodule
