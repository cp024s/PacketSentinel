`timescale 1ns/1ps

module MPD #(
    parameter DATA_WIDTH = 32,
    parameter NUM_SLOTS = 16
)(
    // MPD Signals
    input  logic                          clk,
    input  logic                          rst,

    // Control signals for PRT
    output logic                          EN_start_writing_prt_entry,
    input  logic                          RDY_start_writing_prt_entry,
    input  logic [$clog2(NUM_SLOTS)-1:0]  start_writing_prt_entry,

    output logic                          EN_write_prt_entry,
    input  logic                          RDY_write_prt_entry,
    output logic [DATA_WIDTH-1:0]         write_prt_entry_data,

    output logic                          EN_finish_writing_prt_entry,
    input  logic                          RDY_finish_writing_prt_entry,

    output logic                          EN_invalidate_prt_entry,
    input  logic                          RDY_invalidate_prt_entry,
    output logic [$clog2(NUM_SLOTS)-1:0]  invalidate_prt_entry_slot,

    output logic                          EN_start_reading_prt_entry,
    input  logic                          RDY_start_reading_prt_entry,
    output logic [$clog2(NUM_SLOTS)-1:0]  start_reading_prt_entry_slot,

    output logic                          EN_read_prt_entry,
    input  logic                          RDY_read_prt_entry,
    input  logic [DATA_WIDTH:0]           read_prt_entry,

    input  logic                          is_prt_slot_free,
    input  logic                          RDY_is_prt_slot_free
);

    // Instantiate the PRT module
    PRT #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_SLOTS(NUM_SLOTS)
    ) prt_inst (
        .EN_start_writing_prt_entry (EN_start_writing_prt_entry),
        .RDY_start_writing_prt_entry (RDY_start_writing_prt_entry),
        .start_writing_prt_entry (start_writing_prt_entry),

        .EN_write_prt_entry (EN_write_prt_entry),
        .RDY_write_prt_entry (RDY_write_prt_entry),
        .write_prt_entry_data (write_prt_entry_data),

        .EN_finish_writing_prt_entry (EN_finish_writing_prt_entry),
        .RDY_finish_writing_prt_entry (RDY_finish_writing_prt_entry),

        .EN_invalidate_prt_entry (EN_invalidate_prt_entry),
        .RDY_invalidate_prt_entry (RDY_invalidate_prt_entry),
        .invalidate_prt_entry_slot (invalidate_prt_entry_slot),

        .EN_start_reading_prt_entry (EN_start_reading_prt_entry),
        .RDY_start_reading_prt_entry (RDY_start_reading_prt_entry),
        .start_reading_prt_entry_slot (start_reading_prt_entry_slot),

        .EN_read_prt_entry (EN_read_prt_entry),
        .RDY_read_prt_entry (RDY_read_prt_entry),
        .read_prt_entry (read_prt_entry),

        .is_prt_slot_free (is_prt_slot_free),
        .RDY_is_prt_slot_free (RDY_is_prt_slot_free)
    );

    // MPD logic to control the PRT transactions can go here

endmodule
