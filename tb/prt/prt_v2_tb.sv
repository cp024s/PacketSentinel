`timescale 1ns/1ps

module tb_PRT;
  localparam DATA_WIDTH = 8;
  localparam MEM_DEPTH  = 1518;
  localparam NUM_SLOTS  = 10;

  logic CLK;
  logic RST_N;

  // Write signals
  logic                          EN_start_writing_prt_entry;
  logic                          RDY_start_writing_prt_entry;
  logic [$clog2(NUM_SLOTS)-1:0]  start_writing_prt_entry;

  logic                          EN_write_prt_entry;
  logic                          RDY_write_prt_entry;
  logic [DATA_WIDTH-1:0]         write_prt_entry_data;

  logic                          EN_finish_writing_prt_entry;
  logic                          RDY_finish_writing_prt_entry;

  // Invalidate signals
  logic                          EN_invalidate_prt_entry;
  logic                          RDY_invalidate_prt_entry;
  logic [$clog2(NUM_SLOTS)-1:0]  invalidate_prt_entry_slot;

  // Read signals
  logic                          EN_start_reading_prt_entry;
  logic                          RDY_start_reading_prt_entry;
  logic [$clog2(NUM_SLOTS)-1:0]  start_reading_prt_entry_slot;

  logic                          EN_read_prt_entry;
  logic                          RDY_read_prt_entry;
  logic [DATA_WIDTH:0]           read_prt_entry;

  // Free slot check signals
  logic                          is_prt_slot_free;
  logic                          RDY_is_prt_slot_free;

  PRT #(
    .DATA_WIDTH(DATA_WIDTH),
    .MEM_DEPTH(MEM_DEPTH),
    .NUM_SLOTS(NUM_SLOTS)
  ) dut (
    .CLK(CLK),
    .RST_N(RST_N),

    .EN_start_writing_prt_entry(EN_start_writing_prt_entry),
    .RDY_start_writing_prt_entry(RDY_start_writing_prt_entry),
    .start_writing_prt_entry(start_writing_prt_entry),

    .EN_write_prt_entry(EN_write_prt_entry),
    .RDY_write_prt_entry(RDY_write_prt_entry),
    .write_prt_entry_data(write_prt_entry_data),

    .EN_finish_writing_prt_entry(EN_finish_writing_prt_entry),
    .RDY_finish_writing_prt_entry(RDY_finish_writing_prt_entry),

    .EN_invalidate_prt_entry(EN_invalidate_prt_entry),
    .RDY_invalidate_prt_entry(RDY_invalidate_prt_entry),
    .invalidate_prt_entry_slot(invalidate_prt_entry_slot),

    .EN_start_reading_prt_entry(EN_start_reading_prt_entry),
    .RDY_start_reading_prt_entry(RDY_start_reading_prt_entry),
    .start_reading_prt_entry_slot(start_reading_prt_entry_slot),

    .EN_read_prt_entry(EN_read_prt_entry),
    .RDY_read_prt_entry(RDY_read_prt_entry),
    .read_prt_entry(read_prt_entry),

    .is_prt_slot_free(is_prt_slot_free),
    .RDY_is_prt_slot_free(RDY_is_prt_slot_free)
  );

  // Clock generation
  initial begin
    CLK = 0;
    forever #5 CLK = ~CLK;
  end

  // Reset generation
  initial begin
    RST_N = 0;
    #20 RST_N = 1;
  end

  // Task for writing
  task start_write(input int num_bytes,
                   output logic [$clog2(NUM_SLOTS)-1:0] allocated_slot);
    begin
      wait(is_prt_slot_free);
      EN_start_writing_prt_entry = 1;
      @(posedge CLK);
      EN_start_writing_prt_entry = 0;
      @(posedge CLK);
      allocated_slot = start_writing_prt_entry;
      $display("[%0t] Allocated slot: %0d", $time, allocated_slot);

      for (int i = 0; i < num_bytes; i++) begin
        EN_write_prt_entry = 1;
        write_prt_entry_data = i;
        @(posedge CLK);
        EN_write_prt_entry = 0;
        @(posedge CLK);
        $display("[%0t] Writing byte %0d", $time, i);
      end

      EN_finish_writing_prt_entry = 1;
      @(posedge CLK);
      EN_finish_writing_prt_entry = 0;
      $display("[%0t] Write complete", $time);
    end
  endtask

  // Task for reading
  task start_read(input logic [$clog2(NUM_SLOTS)-1:0] slot, input int num_bytes);
    begin
      start_reading_prt_entry_slot = slot;
      EN_start_reading_prt_entry = 1;
      @(posedge CLK);
      EN_start_reading_prt_entry = 0;
      @(posedge CLK);
      $display("[%0t] Reading from slot: %0d", $time, slot);

      for (int i = 0; i < num_bytes; i++) begin
        EN_read_prt_entry = 1;
        @(posedge CLK);
        EN_read_prt_entry = 0;
        @(posedge CLK);
        $display("[%0t] Read byte %0d: %0d", $time, i, read_prt_entry);
      end
    end
  endtask

  // Task for invalidation
  task invalidate_slot(input logic [$clog2(NUM_SLOTS)-1:0] slot);
    begin
      invalidate_prt_entry_slot = slot;
      EN_invalidate_prt_entry = 1;
      @(posedge CLK);
      EN_invalidate_prt_entry = 0;
      $display("[%0t] Slot %0d invalidated", $time, slot);
    end
  endtask

  initial begin
    logic [$clog2(NUM_SLOTS)-1:0] allocated_slot;
    logic [$clog2(NUM_SLOTS)-1:0] slot_array [NUM_SLOTS];

    // Wait for reset deassertion
    @(negedge RST_N);
    @(posedge RST_N);
    #10;

    // Test 1: Write and Read
    $display("\n--- Test 1: Write and Read ---");
    start_write(5, allocated_slot);
    #10;
    start_read(allocated_slot, 10);
    #10;

    // Test 2: Invalidate and Reuse
    $display("\n--- Test 2: Invalidate and Reuse ---");
    invalidate_slot(allocated_slot);
    #10;
    start_write(5, allocated_slot);
    #10;
    start_read(allocated_slot, 10);
    #10;

    // Test 3: Fill All Slots
    $display("\n--- Test 3: Fill All Slots ---");
    for (int s = 0; s < NUM_SLOTS; s++) begin
      start_write(3, slot_array[s]);
      #5;
    end
    #10;

    if (!is_prt_slot_free)
      $display("[%0t] No free slot available as expected", $time);
    else
      $display("[%0t] ERROR: Free slot reported incorrectly", $time);
    #10;

    // Test 4: Invalidate One Slot and Reuse
    $display("\n--- Test 4: Invalidate and Reuse ---");
    invalidate_slot(slot_array[0]);
    #10;
    start_write(4, allocated_slot);
    #10;
    start_read(allocated_slot, 10);

    #50;
    $display("All tests completed.");
    $finish;
  end
endmodule
