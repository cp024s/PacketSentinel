//Copyright (c) 2021, IIT Madras All rights reserved.
// 
//Redistribution and use in source and binary forms, with or without modification, are permitted
//provided that the following conditions are met:
// 
// - Redistributions of source code must retain the above copyright notice, this list of conditions
// and the following disclaimer. 
// - Redistributions in binary form must reproduce the above copyright notice, this list of 
// conditions and the following disclaimer in the documentation and / or other materials provided 
// with the distribution. 
// - Neither the name of IIT Madras nor the names of its contributors may be used to endorse or 
// promote products derived from this software without specific prior written permission.
 
//THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
//OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
//AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
//CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
//IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT 
//OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//--------------------------------------------------------------------------------------------------
// 
//
// 
// Author : Gnanambikai Krishnakumar
// Email id : gnanukrishna@gmail.com
// #### This is a template file which gives out verilog code that consolidates final match result from submodules ####
// 	
//--------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps 

module final_match#MODULEID#(ip_pro,port_no1,port_no2,result,test_clk); 

parameter n = #NO_OF_RULES#;  // No of Rules before Expansion 
parameter w1 = #W1#;   // No of Bits in Scr Port and Dst Port Fields 
parameter w2 = #W#;   // No of Bits in Src IP, Dst IP and Protocol Fields 
 
input[w1-1:0] port_no1; 
input[w1-1:0] port_no2; 
input[w2-1:0] ip_pro; 
input test_clk; 
output reg result; 
 
wire[n-1:0] final_mv1; 
wire[n-1:0] final_mv2; 
wire[n-1:0] final_mv3; 
reg [n-1:0] final_mv; 

port_match1_#MODULEID# port_match1_#MODULEID#(.port_no(port_no1),.final_mv(final_mv1),.test_clk(test_clk));   // Function for Src Port Range Match 
port_match2_#MODULEID# port_match2_#MODULEID#(.port_no(port_no2),.final_mv(final_mv2),.test_clk(test_clk));   // Function for Dst Port Range Match 
ip_prot_match_#MODULEID# ip_prot_match_#MODULEID#(.ip_pro(ip_pro),.final_mv(final_mv3),.test_clk(test_clk));  // Function for Src IP, Dst IP and Protocol Field Match 

always@(posedge test_clk) 
final_mv = final_mv1 & final_mv2 & final_mv3;       // ANDing the Output of above functions to get a Final Match Vector 

