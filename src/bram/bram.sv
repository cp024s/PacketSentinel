//====================================================================
// Dual-Port BRAM Module
// This module instantiates a dual–port BRAM with one write port and one read port.
// The memory is implemented as a register array that synthesis tools will infer as BRAM.
//====================================================================
module dual_port_bram #(
  parameter DATA_WIDTH = 8,
  parameter ADDR_WIDTH = 12  // For NUM_SLOTS=2 and MEM_DEPTH=1518, ADDR_WIDTH = SLOT_WIDTH + BYTE_ADDR_WIDTH
)(
  input  logic                    CLK,
  // Write port
  input  logic                    wr_en,
  input  logic [ADDR_WIDTH-1:0]   wr_addr,
  input  logic [DATA_WIDTH-1:0]   wr_data,
  // Read port
  input  logic                    rd_en,
  input  logic [ADDR_WIDTH-1:0]   rd_addr,
  output logic [DATA_WIDTH-1:0]   rd_data
);

  // Inferred dual-port BRAM memory array.
  reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

  // Write operation (synchronous)
  always_ff @(posedge CLK) begin
    if (wr_en)
      mem[wr_addr] <= wr_data;
  end

  // Read operation (synchronous)
  always_ff @(posedge CLK) begin
    if (rd_en)
      rd_data <= mem[rd_addr];
  end

endmodule
