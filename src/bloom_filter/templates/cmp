`timescale 1ns / 1ps

module cmp(a,b,eq,lt,gt,test_clk);
parameter w = #COMPSIZE#;
input [w-1:0] a,b;
input test_clk;
output reg eq,lt,gt;

always @(posedge test_clk)
begin
 if (a==b)
 begin
  eq = 1'b1;
  lt = 1'b0;
  gt = 1'b0;
 end
 else if (a>b)
 begin
  eq = 1'b0;
  lt = 1'b0;
  gt = 1'b1;
 end
 else
 begin
  eq = 1'b0;
  lt = 1'b1;
  gt = 1'b0;
 end
end 


endmodule
