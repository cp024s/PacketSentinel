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
// #### This is a template file which gives out verilog code for matching source and destination ip addresses and protocol of the incoming packet with those in the rules ####
// 	
//--------------------------------------------------------------------------------------------------

`timescale 1ns / 1ps
module ip_prot_match_#MODULEID#(ip_pro,final_mv,test_clk);
parameter n2 = #OUTPUT_WIDTH#;
parameter w = #W#;
parameter b = #STRIDE#;
input[w-1:0] ip_pro;
input test_clk;

