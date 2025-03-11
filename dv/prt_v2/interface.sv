interface prt_if(input bit clk, input bit rst_n);
  // Write Transaction signals:
  logic EN_start_writing_prt_entry;
  logic [$clog2(2)-1:0] start_writing_prt_entry;
  logic RDY_start_writing_prt_entry;
  
  logic [7:0] write_prt_entry_data;
  logic EN_write_prt_entry;
  logic RDY_write_prt_entry;
  
  logic EN_finish_writing_prt_entry;
  logic RDY_finish_writing_prt_entry;
  
  // Invalidate Transaction signals:
  logic [$clog2(2)-1:0] invalidate_prt_entry_slot;
  logic EN_invalidate_prt_entry;
  logic RDY_invalidate_prt_entry;
  
  // Read Transaction signals:
  logic [$clog2(2)-1:0] start_reading_prt_entry_slot;
  logic EN_start_reading_prt_entry;
  logic RDY_start_reading_prt_entry;
  
  logic EN_read_prt_entry;
  // DATA_WIDTH+1 bits; here DATA_WIDTH=8 so 9 bits total.
  logic [8:0] read_prt_entry;
  logic RDY_read_prt_entry;
  
  // Free Slot Check:
  logic is_prt_slot_free;
  logic RDY_is_prt_slot_free;
endinterface
