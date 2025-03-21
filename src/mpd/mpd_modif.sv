`timescale 1ns/1ps

module MPD #(
    parameter DATA_WIDTH = 32,
    parameter NUM_SLOTS = 16
)(
    // MPD Signals
    input  logic                          clk,
    input  logic                          rst_n,+

    //====================================================================
    // PRT - BLOOM FILTER COMMUNICATION
    //====================================================================
    input  logic                          enable,
    input  logic [31:0]                   src_ip,
    input  logic [31:0]                   dest_ip,
    input  logic [15:0]                   tag,

    output logic                          safe,
    output logic                          output_valid,
    output logic [63:0]                   header,
    output logic [15:0]                   out_tag,
    output logic                          busy,

    //====================================================================
    // PRT - MPD COMMUNICATION
    //====================================================================
    // -------- Write Transaction Handshake --------
    output logic                          EN_start_writing_prt_entry,
    input  logic                          RDY_start_writing_prt_entry,
    input  logic [$clog2(NUM_SLOTS)-1:0]  start_writing_prt_entry,

    output logic                          EN_write_prt_entry,
    input  logic                          RDY_write_prt_entry,
    output logic [DATA_WIDTH-1:0]         write_prt_entry_data,

    output logic                          EN_finish_writing_prt_entry,
    input  logic                          RDY_finish_writing_prt_entry,

    // -------- Invalidate Transaction Handshake --------
    output logic                          EN_invalidate_prt_entry,
    input  logic                          RDY_invalidate_prt_entry,
    output logic [$clog2(NUM_SLOTS)-1:0]  invalidate_prt_entry_slot,

    // -------- Read Transaction Handshake --------
    output logic                          EN_start_reading_prt_entry,
    input  logic                          RDY_start_reading_prt_entry,
    output logic [$clog2(NUM_SLOTS)-1:0]  start_reading_prt_entry_slot,

    output logic                          EN_read_prt_entry,
    input  logic                          RDY_read_prt_entry,
    input  logic [DATA_WIDTH-1:0]         read_prt_entry,

    // -------- Free Slot Check --------
    input  logic                          is_prt_slot_free,
    input  logic                          RDY_is_prt_slot_free,

    //====================================================================
    // MPD - INPUT FIFO COMMUNICATION
    //====================================================================
    input  logic                          ip_wr_en,
    input  logic                          ip_rd_en,
    input  logic [DATA_WIDTH-1:0]         ip_din,
    output logic [DATA_WIDTH-1:0]         ip_dout,
    output logic                          ip_full,
    output logic                          ip_empty,
    
    //====================================================================
    // PRT - MPD OUTPUT COMMUNICATION
    //====================================================================
    input  logic                          op_wr_en,
    input  logic                          op_rd_en,
    input  logic [DATA_WIDTH-1:0]         op_din,
    output logic [DATA_WIDTH-1:0]         op_dout,
    output logic                          op_full,
    output logic                          op_empty
);

    //====================================================================
    // PACKET REFERENCE TABLE (PRT) INSTANCE
    //====================================================================
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

    //====================================================================
    // BLOOM FILTER INSTANCE
    //====================================================================
    bloom_filter_optimized #(
        .BIT_ARRAY_SIZE(1024),
        .HASH_WIDTH($clog2(1024))
    ) bloom_filter_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .enable       (enable),
        .src_ip       (src_ip),
        .dest_ip      (dest_ip),
        .tag          (tag),
        .safe         (safe),
        .output_valid (output_valid),
        .header       (header),
        .out_tag      (out_tag),
        .busy         (busy)
    );

    //====================================================================
    // INPUT FIFO INSTANCE
    //====================================================================
    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(16),
        .ALMOST_FULL_THRESHOLD(14),
        .ALMOST_EMPTY_THRESHOLD(2)
    ) ip_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(ip_wr_en),
        .rd_en(ip_rd_en),
        .din(ip_din),
        .dout(ip_dout),
        .full(ip_full),
        .empty(ip_empty)
    );

    //====================================================================
    // OUTPUT FIFO INSTANCE
    //====================================================================
    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(16),
        .ALMOST_FULL_THRESHOLD(14),
        .ALMOST_EMPTY_THRESHOLD(2)
    ) op_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(op_wr_en),
        .rd_en(op_rd_en),
        .din(op_din),
        .dout(op_dout),
        .full(op_full),
        .empty(op_empty)
    );

    // MPD's FSM states to be implemented here

endmodule
