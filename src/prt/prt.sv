// ------------------------------
//    PACKET REFERENCE TABLE
// ------------------------------
module PacketReferenceTable (
  input  logic CLK,
  input  logic RST_N,
  
  // START WRITE PRT ENTRY
  input  logic EN_start_writing_prt_entry,
  output logic start_writing_prt_entry,
  output logic RDY_start_writing_prt_entry,

  // WRITE PRT ENTRY
  input  logic [7:0] write_prt_entry_data,
  input  logic EN_write_prt_entry,
  output logic RDY_write_prt_entry,
  
  // FINISH PRT ENTRY
  input  logic EN_finish_writing_prt_entry,
  output logic RDY_finish_writing_prt_entry,

  // INVALIDATE PRT ENTRY
  input  logic invalidate_prt_entry_slot,
  input  logic EN_invalidate_prt_entry,
  output logic RDY_invalidate_prt_entry,

  // START READING PRT ENTRY
  input  logic start_reading_prt_entry_slot,
  input  logic EN_start_reading_prt_entry,
  output logic RDY_start_reading_prt_entry,

  // READ PRT ENTRY
  input  logic EN_read_prt_entry,
  output logic [8 : 0] read_prt_entry,
  output logic RDY_read_prt_entry,

  // IS PRT SLOT FREE
  output logic is_prt_slot_free,
  output logic RDY_is_prt_slot_free
  );

  