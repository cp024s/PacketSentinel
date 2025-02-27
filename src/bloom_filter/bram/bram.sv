module dual_port_bram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 16,
    parameter REGISTERED_OUTPUT = 1,
    parameter INIT_FILE = ""
)(
    input  logic                     clk,
    input  logic                     rst,
    input  logic                     we_a,
    input  logic [ADDR_WIDTH-1:0]    addr_a,
    input  logic [DATA_WIDTH-1:0]    din_a,
    output logic [DATA_WIDTH-1:0]    dout_a,
    input  logic                     we_b,
    input  logic [ADDR_WIDTH-1:0]    addr_b,
    input  logic [DATA_WIDTH-1:0]    din_b,
    output logic [DATA_WIDTH-1:0]    dout_b
);

    logic [DATA_WIDTH-1:0] mem [(2**ADDR_WIDTH)-1:0];
    logic [DATA_WIDTH-1:0] dout_a_next, dout_b_next;

    // Memory initialization
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end else begin
            integer i;
            for (i = 0; i < (2**ADDR_WIDTH); i = i + 1) begin
                mem[i] = '0;
            end
        end
    end

    // Port A logic
    always_ff @(posedge clk) begin
        if (rst) begin
            dout_a_next <= '0;
        end else begin
            if (we_a) begin
                mem[addr_a] <= din_a;
                dout_a_next <= din_a;
            end else begin
                dout_a_next <= mem[addr_a];
            end
        end
    end

    // Port B logic
    always_ff @(posedge clk) begin
        if (rst) begin
            dout_b_next <= '0;
        end else begin
            if (we_b) begin
                mem[addr_b] <= din_b;
                dout_b_next <= din_b;
            end else begin
                dout_b_next <= mem[addr_b];
            end
        end
    end

    assign dout_a = (REGISTERED_OUTPUT) ? dout_a_next : (we_a ? din_a : mem[addr_a]);
    assign dout_b = (REGISTERED_OUTPUT) ? dout_b_next : (we_b ? din_b : mem[addr_b]);

endmodule