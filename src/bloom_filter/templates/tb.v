`timescale 1ns / 1ps

module tb;

parameter w

wire [71:0]ip_pro;
wire [17:0]port1;
wire [17:0]port2;

wire result;
reg clock;      
always begin
    #2.5 clock =!clock;
end
        
initial begin
    clock = 1;
end   
    

topmodule DUT(.ip_protocol(ip_pro),.src_port(port1),.dst_port(port2),.resultCF(result),.test_clk(clock));
          
assign ip_pro = {8'd192,8'd169,8'd1,8'd100, 8'd192,8'd168,8'd1,8'd100,8'd100};
assign port1 = {18'd5};
assign port2 = {18'd10};

    
endmodule
