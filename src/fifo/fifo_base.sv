module fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 16,
    parameter ALMOST_FULL_THRESHOLD = DEPTH - 2,
    parameter ALMOST_EMPTY_THRESHOLD = 2
) (
    input logic clk,
    input logic rst,
    input logic wr_en,
    input logic rd_en,
    input logic [DATA_WIDTH-1:0] din,
    
    output logic [DATA_WIDTH-1:0] dout,
    output logic full,
    output logic empty,
    output logic almost_full,
    output logic almost_empty,
    output logic lookahead_valid,
    output logic [DATA_WIDTH-1:0] lookahead_data
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [$clog2(DEPTH):0] wr_ptr, rd_ptr, count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_ptr] <= din;
                wr_ptr <= wr_ptr + 1;
            end
            if (rd_en && !empty) begin
                dout   <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1;
            end
            if (wr_en && !full && !(rd_en && !empty)) count <= count + 1;
            if (rd_en && !empty && !(wr_en && !full)) count <= count - 1;
        end
    end

    assign full         = (count == DEPTH);
    assign empty        = (count == 0);
    assign almost_full  = (count >= ALMOST_FULL_THRESHOLD);
    assign almost_empty = (count <= ALMOST_EMPTY_THRESHOLD);
    assign lookahead_valid = (count > 0);
    assign lookahead_data  = mem[rd_ptr];

endmodule
