`timescale 1ns/1ps

module MPD #(
    parameter DATA_WIDTH = 32,
    parameter NUM_SLOTS = 16
)(
    // MPD Signals
    input  logic                          CLK,
    input  logic                          RST_N,

    //====================================================================
    // PRT - AXI COMMUNCATION
    //====================================================================

    //====================================================================
    // PRT - BLOOM FILTER COMMUNCATION
    //====================================================================



    //====================================================================
    // PRT - MPD COMMUNCATION
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
    input  logic [DATA_WIDTH:0]           read_prt_entry,
    // -------- Free Slot Check --------
    input  logic                          is_prt_slot_free,
    input  logic                          RDY_is_prt_slot_free
);

//   All the internal logics, registers goes here

// All the state machine logic goes here


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
    bloom_filter #(
        .BIT_ARRAY_SIZE(1024),  // Example size, adjust as needed
        .HASH_WIDTH($clog2(1024))  // Log2 of BIT_ARRAY_SIZE
    ) bloom_filter_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .src_ip(src_ip),
        .dest_ip(dest_ip),
        .tag(tag),
        .safe(safe),
        .output_valid(output_valid),
        .header(header),
        .out_tag(out_tag),
        .busy(busy)
    );

    //====================================================================
    // INPUT FIFO INSTANCE
    //====================================================================
    fifo #(
        .DATA_WIDTH(32),
        .DEPTH(16),
        .ALMOST_FULL_THRESHOLD(14),
        .ALMOST_EMPTY_THRESHOLD(2)
    ) ip_fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .din(din),
        .dout(dout),
        .full(full),
        .empty(empty),
  //  .almost_full(almost_full),
  //  .almost_empty(almost_empty),
  //  .lookahead_valid(lookahead_valid),
  //  .lookahead_data(lookahead_data)
    );
    //====================================================================
    // OUTPUT FIFO INSTANCE
    //====================================================================
    fifo #(
    .DATA_WIDTH(32),
    .DEPTH(16),
    .ALMOST_FULL_THRESHOLD(14),
    .ALMOST_EMPTY_THRESHOLD(2)
    ) op_fifo (
    .clk(clk),
    .rst(rst),
    .wr_en(wr_en),
    .rd_en(rd_en),
    .din(din),
    .dout(dout),
    .full(full),
    .empty(empty),
  //  .almost_full(almost_full),
  //  .almost_empty(almost_empty),
  //  .lookahead_valid(lookahead_valid),
  //  .lookahead_data(lookahead_data)
);


    // MPD's FSM states are to be given here
endmodule
