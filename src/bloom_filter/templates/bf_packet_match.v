  module hash ( input CLK ,input [31:0] a0,b0,c0,k0,k1,input [7:0] k2,output reg [31:0] hashkey );
  reg [31:0] a,b,c,ck,a1,b1,c1,a2,b2,c2,a3,b3,c3,c11,a11,b11,c21,a21,b21,c31;
  always @(posedge CLK)
  begin
  a <=  a0 + k0 ;
  b <=  b0 + k1;
  ck =  k2 & 8'hff;
  c  =  ck + c0;

  end

  always @(posedge CLK)
  begin
  c1  = c ^ b ;
  c11 = c1 - {b[17:0], b[31:18]};
  end
  always @(posedge CLK)
  begin
  a1 = a ^ c11 ;
  a11 = a1 - {c11[20:0], c11[31:21]};
  end
  always @(posedge CLK)
  begin
  b1 = b ^ a11;
  b11= b1 - {a11[6:0], a11[31:7]};
  end 
  always @(posedge CLK)
  begin
  c2 = c11 ^ b11;
  c21 = c2 - {b11[15:0], b11[31:16]};
  end
  always @(posedge CLK)
  begin
  a2 = a11 ^ c21;
  a21= a2 - {c21[27:0], c21[31:28]};
  end
  always @(posedge CLK)
  begin
  b2 = b11 ^ a21 ;
  b21= b2 - {a21[17:0], a21[31:18]};
  end 
  always @(posedge CLK)
  begin
  c3 = c21 ^ b21;
  c31= c3 - {b21[7:0], b21[31:8]};
  end
  always @(posedge CLK)
  begin
  hashkey = c31;
  end  
  endmodule
  

  module hash_port( input CLK ,input [31:0] a0,b0,c0,k01,output reg [31:0] hashkey );
  reg [31:0] a,b,c,ck,a1,b1,c1,a2,b2,c2,a3,b3,c3,c11,a11,b11,c21,a21,b21,c31;
  always @(posedge CLK)
  begin
  a <=  a0 + k01 ;
  b <=  b0 ;
  c <=  c0 ;
  end

  always @(posedge CLK)
  begin
  c1  = c ^ b ;
  c11 = c1 - {b[17:0], b[31:18]};
  end
  always @(posedge CLK)
  begin
  a1 = a ^ c11 ;
  a11 = a1 - {c11[20:0], c11[31:21]};
  end
  always @(posedge CLK)
  begin
  b1 = b ^ a11;
  b11= b1 - {a11[6:0], a11[31:7]};
  end 
  always @(posedge CLK)
  begin
  c2 = c11 ^ b11;
  c21 = c2 - {b11[15:0], b11[31:16]};
  end
  always @(posedge CLK)
  begin
  a2 = a11 ^ c21;
  a21= a2 - {c21[27:0], c21[31:28]};
  end
  always @(posedge CLK)
  begin
  b2 = b11 ^ a21 ;
  b21= b2 - {a21[17:0], a21[31:18]};
  end 
  always @(posedge CLK)
  begin
  c3 = c21 ^ b21;
  c31= c3 - {b21[7:0], b21[31:8]};
  end
  always @(posedge CLK)
  begin
  hashkey = c31;
  end  
  endmodule

