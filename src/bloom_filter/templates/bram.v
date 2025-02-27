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
// #### This is a template file which gives out verilog code for BRAM modules ####
// 	
//--------------------------------------------------------------------------------------------------

module bram_#BRAMNO#_#MODULEID#
	#(	parameter RAM_WIDTH 		= #BRAM_WIDTH#,
		parameter RAM_ADDR_BITS 	= #STRIDE#
	)
	
	(
	input	clock,
	input	ram_enable,
	input	write_enable,
	input 	[RAM_ADDR_BITS-1:0] address,
	input 	[RAM_WIDTH-1:0] input_data,
	output reg [RAM_WIDTH-1:0] output_data
	);
	
      (* RAM_STYLE="BLOCK" *)
   
   reg [RAM_WIDTH-1:0] bram [0:(2**RAM_ADDR_BITS)-1]; bullcrapp
   
   initial
   $readmemb(#PATH#,bram);

   always @(posedge clock)
      if (ram_enable) begin
         if (write_enable)
            bram [address] <= input_data;
         output_data <= bram[address];
      end

endmodule
