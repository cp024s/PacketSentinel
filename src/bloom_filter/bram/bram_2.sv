// bloom_bram.sv
// Dual-ported Block RAM module for the Bloom filter.
// This module implements a 1-bit wide memory array.
// It is written with synchronous resets and includes a ram_style attribute
// so that Vivado infers a true block RAM. In synthesis, initialization (via a COE file)
// is typically handled by tool constraints or attributes.
module bloom_bram #(
  parameter BIT_ARRAY_SIZE = 1024,
  parameter DATA_WIDTH     = 1,
  parameter ADDR_WIDTH     = $clog2(BIT_ARRAY_SIZE)
)(
  input  logic                     clk,
  input  logic                     rst_n,
  // Port 0 interface
  input  logic [ADDR_WIDTH-1:0]    addr0,
  input  logic                     we0,
  input  logic [DATA_WIDTH-1:0]    din0,
  output logic [DATA_WIDTH-1:0]    dout0,
  // Port 1 interface
  input  logic [ADDR_WIDTH-1:0]    addr1,
  input  logic                     we1,
  input  logic [DATA_WIDTH-1:0]    din1,
  output logic [DATA_WIDTH-1:0]    dout1
);

  // Use a synthesis attribute to force block RAM inference.
  (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:BIT_ARRAY_SIZE-1];

  // Synchronous read and write for Port 0 (synchronous reset)
  always_ff @(posedge clk) begin
    if (!rst_n)
      dout0 <= '0;
    else begin
      if (we0)
        mem[addr0] <= din0;
      dout0 <= mem[addr0];
    end
  end

  // Synchronous read and write for Port 1 (synchronous reset)
  always_ff @(posedge clk) begin
    if (!rst_n)
      dout1 <= '0;
    else begin
      if (we1)
        mem[addr1] <= din1;
      dout1 <= mem[addr1];
    end
  end

endmodule
