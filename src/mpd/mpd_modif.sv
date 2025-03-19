
module master_packet_dealer #(parameter DATA_WIDTH = 8, parameter NUM_SLOTS = 4) (
  // ----- Clock and Reset Inputs --------------------------------------------
  input  logic                          CLK,
  input  logic                          RST_N,

  output logic                          EN_start_writing_prt_entry,
  input  logic                          RDY_start_writing_prt_entry,
  input  logic [$clog2(NUM_SLOTS)-1:0]  start_writing_prt_entry,

  // Data transfer: while EN_write_prt_entry is high, one data byte is written per clock cycle.
  output logic                          EN_write_prt_entry,
  input  logic                          RDY_write_prt_entry,
  output logic [DATA_WIDTH-1:0]         write_prt_entry_data,

  // Finish transaction: asserts a one-cycle ready pulse when the write is finalized.
  output logic                          EN_finish_writing_prt_entry,
  input  logic                          RDY_finish_writing_prt_entry,

  // ----- Invalidate Transaction ------
  output logic                          EN_invalidate_prt_entry,
  input  logic                          RDY_invalidate_prt_entry,
  output logic [$clog2(NUM_SLOTS)-1:0]  invalidate_prt_entry_slot,

  // -------- Read Transaction ---------
  output logic                          EN_start_reading_prt_entry,
  input  logic                          RDY_start_reading_prt_entry,
  output logic [$clog2(NUM_SLOTS)-1:0]  start_reading_prt_entry_slot,

  // Data transfer: while EN_read_prt_entry is high, one byte is output per clock cycle.
  output logic                          EN_read_prt_entry,
  input  logic                          RDY_read_prt_entry,

  // The read bus is DATA_WIDTH+1 bits wide. The extra MSB indicates if the read is complete.
  input  logic [DATA_WIDTH:0]           read_prt_entry,
  
  // --------- Free Slot Check ---------
  input  logic                          is_prt_slot_free,
  input  logic                          RDY_is_prt_slot_free
