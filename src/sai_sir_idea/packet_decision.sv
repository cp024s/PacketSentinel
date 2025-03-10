module packet_decision (
    input  logic       clk,
    input  logic       rst,
    input  logic       block_packet,
    // AXI-Stream input (from the RGMII RX or parser)
    input  logic [7:0] axis_in_tdata,
    input  logic       axis_in_tvalid,
    input  logic       axis_in_tlast,
    // AXI-Stream output (to the RGMII TX)
    output logic [7:0] axis_out_tdata,
    output logic       axis_out_tvalid,
    output logic       axis_out_tlast
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            axis_out_tdata  <= 8'd0;
            axis_out_tvalid <= 1'b0;
            axis_out_tlast  <= 1'b0;
        end else begin
            if (block_packet) begin
                // Drop the packet: do not forward any data.
                axis_out_tvalid <= 1'b0;
            end else begin
                // Pass through the incoming data.
                axis_out_tdata  <= axis_in_tdata;
                axis_out_tvalid <= axis_in_tvalid;
                axis_out_tlast  <= axis_in_tlast;
            end
        end
    end
endmodule
