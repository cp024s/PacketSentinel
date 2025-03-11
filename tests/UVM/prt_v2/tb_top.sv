`timescale 1ns/1ps
import uvm_pkg::*;
`include "uvm_macros.svh"

module tb_top;
  // Instantiate the interface
  prt_if prt_if_inst(.clk(), .rst_n());
  
  // Clock and reset generation
  logic clk;
  logic rst_n;
  
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 10 ns period
  end
  
  initial begin
    rst_n = 0;
    #20; rst_n = 1;
  end
  
  // Connect clock and reset to interface
  assign prt_if_inst.clk = clk;
  assign prt_if_inst.rst_n = rst_n;
  
  // Instantiate the DUT
  PRT #(
    .DATA_WIDTH(8),
    .MEM_DEPTH(1518),
    .NUM_SLOTS(2)
  ) dut (
    .CLK(prt_if_inst.clk),
    .RST_N(prt_if_inst.rst_n),
    .EN_start_writing_prt_entry(prt_if_inst.EN_start_writing_prt_entry),
    .start_writing_prt_entry(prt_if_inst.start_writing_prt_entry),
    .RDY_start_writing_prt_entry(prt_if_inst.RDY_start_writing_prt_entry),
    .write_prt_entry_data(prt_if_inst.write_prt_entry_data),
    .EN_write_prt_entry(prt_if_inst.EN_write_prt_entry),
    .RDY_write_prt_entry(prt_if_inst.RDY_write_prt_entry),
    .EN_finish_writing_prt_entry(prt_if_inst.EN_finish_writing_prt_entry),
    .RDY_finish_writing_prt_entry(prt_if_inst.RDY_finish_writing_prt_entry),
    .invalidate_prt_entry_slot(prt_if_inst.invalidate_prt_entry_slot),
    .EN_invalidate_prt_entry(prt_if_inst.EN_invalidate_prt_entry),
    .RDY_invalidate_prt_entry(prt_if_inst.RDY_invalidate_prt_entry),
    .start_reading_prt_entry_slot(prt_if_inst.start_reading_prt_entry_slot),
    .EN_start_reading_prt_entry(prt_if_inst.EN_start_reading_prt_entry),
    .RDY_start_reading_prt_entry(prt_if_inst.RDY_start_reading_prt_entry),
    .EN_read_prt_entry(prt_if_inst.EN_read_prt_entry),
    .read_prt_entry(prt_if_inst.read_prt_entry),
    .RDY_read_prt_entry(prt_if_inst.RDY_read_prt_entry),
    .is_prt_slot_free(prt_if_inst.is_prt_slot_free),
    .RDY_is_prt_slot_free(prt_if_inst.RDY_is_prt_slot_free)
  );
  
  // Run the UVM test
  initial begin
    uvm_config_db#(virtual prt_if)::set(null, "*", "vif", prt_if_inst);
    run_test("prt_test");
  end
  
endmodule
