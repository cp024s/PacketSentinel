
#Copyright (c) 2021, IIT Madras All rights reserved.
# 
#Redistribution and use in source and binary forms, with or without modification, are permitted
#provided that the following conditions are met:
# 
#* Redistributions of source code must retain the above copyright notice, this list of conditions
# and the following disclaimer. 
#* Redistributions in binary form must reproduce the above copyright notice, this list of 
# conditions and the following disclaimer in the documentation and / or other materials provided 
# with the distribution. 
#* Neither the name of IIT Madras nor the names of its contributors may be used to endorse or 
# promote products derived from this software without specific prior written permission.
 
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
#OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
#AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
#CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
#IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT 
#OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#--------------------------------------------------------------------------------------------------
# 
#Author : Gnanambikai Krishnakumar
#Email id : gnanukrishna@gmail.com
#Details: 
# 
#This code generates verilog source files (srcfiles/, dramfiles/) based on user input.
#--------------------------------------------------------------------------------------------------
import os
import re
import math
class DRAM:
	def __init__(self, template_file, srcfiles_loc, memfiles_loc, W, stride, dram_depth, no_of_rules,keyword, keyword1):
		self.template_file = template_file
		self.srcfiles_loc = srcfiles_loc
		self.stride = stride
		self.no_of_rules = no_of_rules
		self.dram_depth = dram_depth
		self.W = W
		self.memfiles_loc = memfiles_loc
		self.keyword = keyword
		self.keyword1 = keyword1
	
	def generateSource(self):
		# open template file.
		template = open(self.template_file,"r")
		tcontent = template.read()
		tcontent = re.sub("#NO_OF_RULES#",str(self.no_of_rules-1),tcontent)
		tcontent = re.sub("#DRAM_DEPTH#",str(self.dram_depth-1),tcontent)
		tcontent = re.sub("#STRIDE#",str(self.stride-1),tcontent)
		tcontent = re.sub("#MODULEID#",str(self.keyword1),tcontent)
		tcontent = re.sub("#### [a-zA-Z ]+ ####","/* Auto-generated code. */\n /* DO NOT MODIFY THIS FILE DIRECTLY.*/\n/* ANY CHANGES SHOULD BE MADE TO THE CORRESPONDING TEMPLATE FILE*/\n",tcontent);

		template.close()	
		noOfBlocks = self.W//self.stride
		## Generate DRAM Files for IP_Prot_Match Module ##
		for i in range(0,noOfBlocks):
			content = tcontent
			path=self.srcfiles_loc+"dramfiles/"
			if(os.path.isdir(path) is False):
				os.mkdir(path)
			
			file1=open(path+"dist_"+self.keyword+str(i)+"_"+self.keyword1+".v","w+")
			content = re.sub("#DRAMNO#",self.keyword+str(i),content)
			path="\""+self.memfiles_loc+"stride"+str(self.stride)+"_"+str(self.W)+"bit"+str(i)+".mem\""
			content = re.sub("#PATH#",path,content)
			file1.write(content)
			file1.close()

class BRAM:
	def __init__(self, template_file, srcfiles_loc, memfiles_loc, W, stride, bram_width,keyword, keyword1):
		self.template_file = template_file
		self.srcfiles_loc = srcfiles_loc
		self.stride = stride
		self.bram_width = bram_width
		self.W = W
		self.memfiles_loc = memfiles_loc
		self.keyword = keyword
		self.keyword1 = keyword1	
	def generateSource(self):
		# open template file.
		template = open(self.template_file,"r")
		tcontent = template.read()
		tcontent = re.sub("#BRAM_WIDTH#",str(self.bram_width),tcontent)
		tcontent = re.sub("#STRIDE#",str(self.stride),tcontent)
		tcontent = re.sub("#MODULEID#",str(self.keyword1),tcontent)
		tcontent = re.sub("#### [a-zA-Z ]+ ####","/* Auto-generated code. */\n /* DO NOT MODIFY THIS FILE DIRECTLY.*/\n/* #ANY CHANGES SHOULD BE MADE TO THE CORRESPONDING TEMPLATE FILE*/\n",tcontent);	

		template.close()	
		noOfBlocks = int(self.W//self.stride)
		for i in range(0,noOfBlocks):
			content = tcontent
			path=self.srcfiles_loc+"bramfiles/"
			if(os.path.isdir(path) is False):
				os.mkdir(path)
			
			file1=open(path+"bram_"+self.keyword+str(i)+"_"+self.keyword1+".v","w+")
			
			content = re.sub("#BRAMNO#",self.keyword+str(i),content)
			if(self.keyword=="bloom"):
				path="\""+self.memfiles_loc+"bloomfilter.mem\""
			else:
				path="\""+self.memfiles_loc+"stride"+str(self.stride)+"_"+str(self.W)+"bit"+str(i)+".mem\""
			content = re.sub("#PATH#",path,content)
			file1.write(content)
			file1.close()

class Consolidator:
	def __init__(self, template_file, srcfiles_loc, W, W1, stride, no_of_instances, rangeMatching):
		self.template_file = template_file
		self.srcfiles_loc = srcfiles_loc
		self.W = W
		self.W1 = W1
		self.stride = stride
		self.no_of_instances = no_of_instances
		self.rangeMatching = rangeMatching
	
	
	def generateSource(self):
			
		# open template file.
		template = open(self.template_file,"r")
		tcontent = template.read()
		template.close()
		
		if(self.rangeMatching):
			keyword1 = "_rm"
		else:
			keyword1 = "_wrm"
			
		tcontent = re.sub("#KEYWORD#", keyword1, tcontent)
		tcontent = re.sub("#NO_OF_INSTANCES#",str(self.no_of_instances),tcontent)
		tcontent = re.sub("#W1#",str(self.W1),tcontent)
		tcontent = re.sub("#W#",str(self.W),tcontent)	
		tcontent = re.sub("#### [a-zA-Z ]+ ####","/* Auto-generated code. */\n /* DO NOT MODIFY THIS FILE DIRECTLY.*/\n/* #ANY CHANGES SHOULD BE MADE TO THE CORRESPONDING TEMPLATE FILE*/\n",tcontent)
		buf = ""
		
		for i in range(self.no_of_instances):
			buf = buf + "wire moduleResult"+str(i)+";\n"
		for i in range(self.no_of_instances):
			buf = buf + "final_match"+str(i)+keyword1+" final_match"+str(i)+keyword1+"(.port_no1(src_port),.port_no2(dst_port),.ip_pro(ip_protocol),.result(moduleResult"+str(i)+"),.test_clk(test_clk));\n"
			
		buf = buf + "always @(posedge test_clk)\n"
		buf = buf + "begin\n"			
		buf = buf + "resultC = "
		i=-1
		for i in range(self.no_of_instances-1):
			buf = buf + "moduleResult"+str(i)+" | "
			
		buf = buf + "moduleResult"+str(i+1)+";\n"
		buf = buf + "end\n"
		buf = buf + "endmodule\n"
		path=self.srcfiles_loc+"srcfiles/"
		if(os.path.isdir(path) is False):
			os.mkdir(path)	

		if(self.rangeMatching):
			outputfile = open(path+"consolidator_rm.v","w+")
		else:
			outputfile = open(path+"consolidator_wrm.v","w+")
			
		outputfile.write(tcontent+buf)
		outputfile.close()

class FinalMatch:
	def __init__(self, template_file, srcfiles_loc, W, W1, stride, no_of_rules, keyword):
		self.template_file = template_file
		self.srcfiles_loc = srcfiles_loc
		self.W = W
		self.W1 = W1
		self.stride = stride
		self.no_of_rules = no_of_rules
		self.keyword = keyword
	
	
	def generateSource(self):
		## Generating the Verilog Code FinalMatch.v ##
			
		# open template file.
		template = open(self.template_file,"r")
		tcontent = template.read()
		template.close()
		
		tcontent = re.sub("#NO_OF_RULES#",str(self.no_of_rules),tcontent)
		tcontent = re.sub("#W1#",str(self.W1),tcontent)
		tcontent = re.sub("#W#",str(self.W),tcontent)
		tcontent = re.sub("#MODULEID#",str(self.keyword),tcontent)	
		tcontent = re.sub("#### [a-zA-Z ]+ ####","/* Auto-generated code. */\n /* DO NOT MODIFY THIS FILE DIRECTLY.*/\n/* #ANY CHANGES SHOULD BE MADE TO THE CORRESPONDING TEMPLATE FILE*/\n",tcontent)
		
		
		noOfLevels = int(math.ceil(math.log(self.no_of_rules,self.stride)))
		n = self.no_of_rules
		buf=""
		prev_n = self.no_of_rules
		for i in range(noOfLevels):
			if(n % self.stride ==0 or n//self.stride ==0): 
				length = n//self.stride
			else:
				length=n//self.stride + 1	
			
			n = n//self.stride
			if(length!=0):
				buf = buf + "reg ["+str(length-1)+":0] level"+str(i)+";\n"
			buf = buf + "always@(posedge test_clk) \n"
			buf = buf + "begin \n"
			if(length!=0):
				for j in range(length):
					if(length==0):
						buf = buf+"\tresult="
					else:
						buf = buf+"\tlevel"+str(i)+"["+str(j)+"] = "
						
					if(i==0):
						input_reg = "final_mv"
					else:
						input_reg = "level"+str(i-1)
						lesserThanStride=0
					for k in range(self.stride-1):
						index = j*self.stride+k
						if(index < prev_n-2):
							buf = buf + input_reg+"["+str(index)+"] | "
						else:
							lesserThanStride=1
							k = k-1
							break
							
					if(lesserThanStride):
						buf = buf + input_reg+"["+str(j*self.stride+k+1)+"];\n"
					else:
						buf = buf + input_reg+"["+str(j*self.stride+k+1)+"];\n"
			else:
				buf = buf+"\tresult="
				if(i==0):
					input_reg = "final_mv"
				else:
					input_reg = "level"+str(i-1)
				
				for k in range(self.stride-1):
					index = k
					if(index < prev_n-2):
						buf = buf + input_reg+"["+str(index)+"] | "
					else:
						k=k-1
						break			
				buf = buf + input_reg+"["+str(k+1)+"];\n"

			buf = buf + "end\n\n"
			prev_n = length+1	
			
			if(self.no_of_rules==1):
				buf = buf + "always@(posedge test_clk) \n"
				buf = buf + "begin\n result = final_mv; \n end\n";

		buf = buf + "endmodule"
		path=self.srcfiles_loc+"srcfiles/"
		if(os.path.isdir(path) is False):
			os.mkdir(path)		
		outputfile = open(path+"final_match"+self.keyword+".v","w+")
		outputfile.write(tcontent+buf)
		outputfile.close()
		
class IPPROT_MATCH:
	def __init__(self, template_file, srcfiles_loc, W, stride, output_width, isDram, keyword):
		self.template_file = template_file
		self.srcfiles_loc = srcfiles_loc
		self.W = W
		self.stride = stride
		self.output_width = output_width
		self.isDram = isDram		
		self.keyword  = keyword
		
	def generateSource(self):
		# open template file.
		template = open(self.template_file,"r")
		tcontent = template.read()
		template.close()
		
		tcontent = re.sub("#OUTPUT_WIDTH#",str(self.output_width),tcontent)
		tcontent = re.sub("#STRIDE#",str(self.stride),tcontent)
		tcontent = re.sub("#W#",str(self.W),tcontent)
		tcontent = re.sub("#MODULEID#",self.keyword,tcontent)
		tcontent = re.sub("#### [a-zA-Z ]+ ####","/* Auto-generated code. */\n /* DO NOT MODIFY THIS FILE DIRECTLY.*/\n/* #ANY CHANGES SHOULD BE MADE TO THE CORRESPONDING TEMPLATE FILE*/\n",tcontent);
	
		noOfBlocks = self.W//self.stride
	
		buf=""
		buf=buf+"// wire to store o/p of IP and Protocol DRAM \n\n"

		for i in range(noOfBlocks):
			buf=buf+"wire[n2-1:0] ip_temp"+str(i+1)+"; \n\n"

		for i in range(noOfBlocks):
			buf=buf+"reg [n2-1:0] ip_reg"+str(i)+"; \n\n"

		buf=buf+"\noutput reg[n2-1:0] final_mv; \n"
		buf=buf+"\n // IP_Pro DRAM Match \n\n"

		if(self.isDram):
			buf=buf+"reg data; \n\n"
			for i in range(noOfBlocks):
				buf=buf+"dist_ipprot"+str(i)+"_"+self.keyword+" dist_ipprot"+str(i)+"_"+self.keyword+"(.data(data),.addr0(ip_pro["+str(self.stride*(i+1)-1)+":"+str(i*self.stride)+"]),.we(1'b0), .clk(test_clk),.q0(ip_temp"+str(i+1)+")); \n"
		else:
			buf=buf+"reg [n2-1:0] data; \n\n"
			for i in range(noOfBlocks):
				buf=buf+"bram_ipprot"+str(i)+"_"+self.keyword+" bram"+str(i)+"_"+self.keyword+"(.clock(test_clk),.ram_enable(1'b1),.write_enable(1'b0),.address(ip_pro["+str(self.stride*(i+1)-1)+":"+str(i*self.stride)+"]),.input_data(data),.output_data(ip_temp"+str(i+1)+"));\n"

		buf=buf+"\nalways@(posedge test_clk) \n"
		buf=buf+"begin \n"

		for i in range(noOfBlocks):
			buf=buf+"ip_reg"+str(i)+" =  ip_temp"+str(i+1)+"; \n"
		buf=buf+"end \n"

		n = noOfBlocks
		prev_n = noOfBlocks
		noOfLevels = int(math.ceil(math.log(noOfBlocks,self.stride)))
		
		
		buf1=""
		noOfLevels = int(math.ceil(math.log(noOfBlocks,self.stride)))
#		print(noOfLevels)
		n = noOfBlocks
		prev_n = noOfBlocks
		for i in range(noOfLevels):			
			if(n % self.stride ==0 or n//self.stride ==0): 
				length = n//self.stride
			else:
				length=n//self.stride + 1	
				
			n = n//self.stride			
			if(length!=0):
				for j in range(length):
					buf1=buf1+"\nreg [n2-1:0] final_match"+str(j)+"; \n"
				buf1 = buf1 + "always@(posedge test_clk) \n"
				buf1 = buf1 + "begin \n"
				
				for j in range(length):
					buf1 = buf1+"\tfinal_match"+str(j)+" = "						
					if(i==0):
						input_reg = "ip_reg"
					else:
						input_reg = "final_match"
						lesserThanStride=0	
					for k in range(self.stride-1):
						index = j*self.stride+k
						if(index < prev_n-2):
							buf1 = buf1 + input_reg+str(index)+" & "
						else:
							lesserThanStride=1
							k = k-1
							break
						
						if(lesserThanStride):	
							buf1 = buf1 + input_reg+str(j*self.stride+k+1)+";\n"
						else:
							buf1 = buf1 + input_reg+str(j*self.stride+k+1)+";\n"
			else:
				buf1 = buf1 + "always@(posedge test_clk) \n"
				buf1 = buf1 + "begin \n"
				buf1 = buf1+"\tfinal_mv="
				if(i==0):
					input_reg = "ip_reg"
				else:
					input_reg = "final_match"
				for k in range(self.stride-1):
					index = k
					lesserThanStride=0
					if(index < prev_n-2):
						buf1 = buf1 + input_reg+str(index)+" & "
					else:
						lesserThanStride=1
						k = k -1
						break
					
					if(lesserThanStride):
						buf1 = buf1 + input_reg+str(k+1)+";\n"		
					else:
						buf1 = buf1 + input_reg+str(k+1)+";\n"		

			buf1 = buf1 + "end\n"
			prev_n = length+1
			
		buf = buf + buf1 + "\n endmodule\n";
		path=self.srcfiles_loc+"srcfiles/"
		if(os.path.isdir(path) is False):
			os.mkdir(path)				
		outputfile = open(path+"ip_prot_match_"+self.keyword+".v","w+")
		outputfile.write(tcontent+buf)
		outputfile.close()
		
class PORT_MATCH:
	def __init__(self, template_file, srcfiles_loc, W, stride, output_width, port_num, isDram, keyword):
		self.template_file = template_file
		self.srcfiles_loc = srcfiles_loc
		self.W = W
		self.stride = stride
		self.output_width = output_width
		self.port_num = port_num	
		self.isDram = isDram
		self.keyword = keyword
		
	def generateSource(self):
		# open template file.
		template = open(self.template_file,"r")
		tcontent = template.read()
		template.close()
		
		tcontent = re.sub("#OUTPUT_WIDTH#",str(self.output_width),tcontent)
		tcontent = re.sub("#STRIDE#",str(self.stride),tcontent)
		tcontent = re.sub("#W#",str(self.W),tcontent)	
		tcontent = re.sub("#PORT_NUM#",str(self.port_num),tcontent)
		tcontent = re.sub("#MODULEID#",str(self.keyword),tcontent)
		tcontent = re.sub("#### [a-zA-Z ]+ ####","/* Auto-generated code. */\n /* DO NOT MODIFY THIS FILE DIRECTLY.*/\n/* #ANY CHANGES SHOULD BE MADE TO THE CORRESPONDING TEMPLATE FILE*/\n",tcontent);
	
		noOfBlocks = self.W//self.stride
		
		buf=""
		
		for i in range(noOfBlocks):
			buf=buf+"wire [n-1:0] temp"+str(i)+";\n"

		for i in range(noOfBlocks):
			buf=buf+"reg [n-1:0] reg"+str(i)+";\n"
			
		for i in range(noOfBlocks):
			buf=buf+"reg ["+str(self.stride-1)+":0] temp_loc"+str(i)+";\n"
		
		buf = buf + "always@(posedge test_clk)\nbegin\n"
		
		k=1
		for i in range(noOfBlocks-1,-1,-1):
			maxid = k*self.stride-1
			minid = (k-1)*self.stride		
			buf=buf+"case(port_no["+str(maxid)+":"+str(minid)+"])\n"
			for j in range(int(math.pow(2,self.stride))):
				buf=buf+"'d"+str(j)+" :  temp_loc"+str(k-1)+"='d"+str(j)+";\n"
			buf=buf+"endcase\n"
			k=k+1
		buf=buf+"end\n"
		
		if(self.port_num==1):
			keyword="srcport"
		else:
			keyword="dstport"

		if(self.isDram):			
			buf=buf+"reg data; \n\n"
			for i in range(noOfBlocks):
				buf=buf+"dist_"+keyword+str(i)+"_"+self.keyword+" dist_"+keyword+str(i)+"_"+self.keyword+"(.data(data),.addr0(temp_loc"+str(i)+"),.we(1'b0), .clk(test_clk),.q0(temp"+str(i)+"));\n"
		else:			
			buf=buf+"reg [n-1:0] data; \n\n"
			for i in range(noOfBlocks):
				buf=buf+"bram_"+keyword+str(i)+"_"+self.keyword+" bram_"+keyword+str(i)+"_"+self.keyword+"(.clock(test_clk),.ram_enable(1'b1),.write_enable(1'b0),.address(temp_loc"+str(i)+"),.input_data(data),.output_data(temp"+str(i)+"));\n"
			

		buf=buf+"always@(posedge test_clk)\nbegin\n"
		for i in range(noOfBlocks):
			buf=buf+"reg"+str(i)+"=temp"+str(i)+";\n"
			
		buf=buf+"end\n"
		buf=buf+"always@(posedge test_clk)\n"
		buf=buf+"final_mv = "
		for i in range(noOfBlocks-1):
			buf=buf+"reg"+str(i)+"&"
		buf=buf+"reg"+str(i+1)+";\n"
		buf = buf + "\n endmodule\n"
		path=self.srcfiles_loc+"srcfiles/"
		if(os.path.isdir(path) is False):
			os.mkdir(path)		
		
		outputfile = open(path+"port_match"+str(self.port_num)+"_"+self.keyword+".v","w+")
		outputfile.write(tcontent+buf)
		outputfile.close()
	
class PORT_MATCH_WITH_RANGES:		
	def __init__(self, template_file, srcfiles_loc, W, stride, output_width, port_num, isDram, keyword, ctr, sign_f):
		self.template_file = template_file
		self.srcfiles_loc = srcfiles_loc
		self.W = W
		self.stride = stride
		self.output_width = output_width
		self.port_num = port_num	
		self.isDram = isDram
		self.keyword = keyword
		self.ctr = ctr
		self.sign_f = sign_f
		
	def generateSource(self):
		# open template file.
		template = open(self.template_file,"r")
		tcontent = template.read()
		template.close()
		
		tcontent = re.sub("#OUTPUT_WIDTH#",str(self.output_width),tcontent)
		tcontent = re.sub("#STRIDE#",str(self.stride),tcontent)
		tcontent = re.sub("#W#",str(self.W),tcontent)	
		tcontent = re.sub("#PORT_NUM#",str(self.port_num),tcontent)
		tcontent = re.sub("#MODULEID#",str(self.keyword),tcontent)
		tcontent = re.sub("#NO_OF_RULES_AFTER_EXPANSION#", str(self.ctr[-1]), tcontent) # last element in the ctr array should contain the last index of the expanded rule set.
		tcontent = re.sub("#### [a-zA-Z ]+ ####","/* Auto-generated code. */\n /* DO NOT MODIFY THIS FILE DIRECTLY.*/\n/* #ANY CHANGES SHOULD BE MADE TO THE CORRESPONDING TEMPLATE FILE*/\n",tcontent);

		noOfBlocks = self.W//self.stride
		
		buf=""

		for i in range(noOfBlocks):
			buf=buf+"wire [n-1:0] temp"+str(i)+";\n"

		for i in range(noOfBlocks):
			buf=buf+"reg [n-1:0] reg"+str(i)+";\n"
			
		for i in range(noOfBlocks):
			buf=buf+"reg ["+str(self.stride-1)+":0] temp_loc"+str(i)+";\n"
		buf = buf + "always@(posedge test_clk)\nbegin\n"
		
		k=1
		for i in range(noOfBlocks-1,-1,-1):
			maxid = k*self.stride-1
			minid = (k-1)*self.stride		
			buf=buf+"case(port_no["+str(maxid)+":"+str(minid)+"])\n"
			for j in range(int(math.pow(2,self.stride))):
				buf=buf+"'d"+str(j)+" :  temp_loc"+str(k-1)+"='d"+str(j)+";\n"
			buf=buf+"endcase\n"
			k=k+1
		buf=buf+"end\n"
		
		if(self.port_num==1):
			keyword="srcport"
		else:
			keyword="dstport"

		if(self.isDram):			
			buf=buf+"reg data; \n\n"
			for i in range(noOfBlocks):
				buf=buf+"dist_"+keyword+str(i)+"_"+self.keyword+" dist_"+keyword+str(i)+"_"+self.keyword+"(.data(data),.addr0(temp_loc"+str(i)+"),.we(1'b0), .clk(test_clk),.q0(temp"+str(i)+"));\n"
		else:
			buf=buf+"reg [n-1:0] data; \n\n"
			for i in range(noOfBlocks):
				buf=buf+"bram_"+keyword+str(i)+"_"+self.keyword+" bram_"+keyword+str(i)+"_"+self.keyword+"(.clock(test_clk),.ram_enable(1'b1),.write_enable(1'b0),.address(temp_loc"+str(i)+"),.input_data(data),.output_data(temp"+str(i)+"));\n"	

		buf=buf+"always@(posedge test_clk)\nbegin\n"
		for i in range(noOfBlocks):
			buf=buf+"reg"+str(i)+"=temp"+str(i)+";\n"
			
		buf=buf+"end\n"
		buf=buf+"always@(posedge test_clk)\n"
		buf=buf+"final_match = "
		for i in range(noOfBlocks-1):
			buf=buf+"reg"+str(i)+"&"
		buf=buf+"reg"+str(i+1)+";\n"
		
		buf = buf + "always@(posedge test_clk)\nbegin\n"

		for i in range(0,self.output_width):
			p=[]
			n=[]
			for j in range(self.ctr[i],self.ctr[i+1]):
				if (self.sign_f[j]==0):
					p.append(j)
				elif (self.sign_f[j]==1):
					n.append(j)
				
			buf = buf + "final_mvp["+str(i)+"]="
			
			if(len(p)==0):
				buf = buf + "0;\n"
			else:  
				buf = buf + "("
			for k in range(len(p)):  
				if (k!=len(p)-1):
					buf = buf + "final_match["+str(p[k])+"] | "
				elif (k==len(p)-1):
					buf = buf + "final_match["+str(p[k])+"] );\n"
			
			buf = buf + "final_mvn["+str(i)+"]="
			
			if(len(n)==0):
				buf = buf + "0;\n"
			else:
				buf = buf + "("
			
			for k in range(len(n)):
				if (k!=len(n)-1):
					buf = buf + "final_match["+str(n[k])+"] | "
				elif (k==len(n)-1):
					buf = buf + "final_match["+str(n[k])+"]);\n"
					
			buf = buf + "final_mv["+str(i)+"] = final_mvp["+str(i)+"] &~ final_mvn["+str(i)+"];\n"

		buf = buf + "\nend\n"
		buf = buf + "endmodule\n"
		
		path=self.srcfiles_loc+"srcfiles/"
		if(os.path.isdir(path) is False):
			os.mkdir(path)		
		
		outputfile = open(path+"port_match"+str(self.port_num)+"_"+self.keyword+".v","w+")
		outputfile.write(tcontent+buf)
		outputfile.close()						
				
		
class PORT_MATCH_WITH_RANGES_COMP:
	def __init__ (self, template_loc, srcfiles_loc, stride, noOfRules, port_num, rangeList, keyword, port_width):
		self.template_loc = template_loc
		self.srcfiles_loc = srcfiles_loc
		self.stride = stride
		self.port_num = port_num
		self.noOfRules = noOfRules
		self.rangeList = rangeList      
		self.keyword = keyword
		self.port_width = port_width
	
	def generateSource(self):
		# open template file for port comparison
		template = open(self.template_loc+"comparator","r")
		tcontent = template.read()
		template.close()
		
		tcontent = re.sub("#COMPSIZE#",str(self.port_width),tcontent) 
		tcontent = re.sub("#PORT_NUM#",str(self.port_num),tcontent)
		tcontent = re.sub("#MODULEID#",str(self.keyword),tcontent)
		tcontent = re.sub("#NO_OF_RULES#", str(self.noOfRules), tcontent)
		
		buf = ""
		for i in range(self.noOfRules):
			buf=buf+"wire [w-1:0] minVal"+str(i)+";\n"
			
		for i in range(self.noOfRules):
			buf=buf+"wire [w-1:0] maxVal"+str(i)+";\n"

		for i in range(self.noOfRules):
			buf=buf+"wire eqmin"+str(i)+",ltmin"+str(i)+",gtmin"+str(i)+",eqmax"+str(i)+",ltmax"+str(i)+",gtmax"+str(i)+",ir"+str(i)+";\n"
			
			buf = buf + "assign minVal"+str(i)+" = { "+str(self.port_width)+"'d"+str(self.rangeList[0][i])+"};\n"
			buf = buf + "assign maxVal"+str(i)+" = {"+str(self.port_width)+"'d"+str(self.rangeList[1][i])+"};\n"
			buf = buf + "cmp minComp"+str(i)+"(.a(port_no),.b(minVal"+str(i)+"),.eq(eqmin"+str(i)+"),.lt(ltmin"+str(i)+"),.gt(gtmin"+str(i)+"),.test_clk(test_clk));\n"
			buf = buf + "cmp maxComp"+str(i)+"(.a(port_no),.b(maxVal"+str(i)+"),.eq(eqmax"+str(i)+"),.lt(ltmax"+str(i)+"),.gt(gtmax"+str(i)+"),.test_clk(test_clk));\n"
			
			buf = buf + "assign ir"+str(i)+" = ((eqmin"+str(i)+" | gtmin"+str(i)+") & (~ltmin"+str(i)+")) & ((eqmax"+str(i)+" | ltmax"+str(i)+") & (~gtmax"+str(i)+"));\n"
			
			buf = buf + "always @(posedge test_clk)\nbegin\nfinal_mv= {ir"+str(self.noOfRules-1)
		
		for i in range(self.noOfRules-2,-1,-1):
			buf = buf + ",ir"+str(i)
			
		buf = buf + "};\nend\nendmodule"
		
		path=self.srcfiles_loc+"srcfiles/"
		
		if(os.path.isdir(path) is False):
			os.mkdir(path)		
			
			outputfile = open(path+"port_match"+str(self.port_num)+"_"+self.keyword+".v","w+")
			outputfile.write(tcontent+buf)
			outputfile.close()						
			
		# open template file for comparator
		template = open(self.template_loc+"cmp","r")
		tcontent = template.read()
		template.close()
		
		tcontent = re.sub("#COMPSIZE#",str(self.port_width),tcontent) 
		compFile = path+"cmp.v"
		if(not os.path.isfile(compFile)):
			outputfile = open(compFile,"w+")
			outputfile.write(tcontent)
			outputfile.close()						
            	
class BF_PACKET_MATCH:
	def __init__ (self, template_loc, srcfiles_loc, m, k, keyword):
		self.template_loc = template_loc
		self.srcfiles_loc = srcfiles_loc
		self.keyword = keyword	
		self.m = m
		self.k = k
	
	def generateSource(self):
		commoncode1_1="module final_match{} (input test_clk, input[15:0] port_no1, input[15:0] port_no2, input[71:0] ip_pro, output result);".format(self.keyword)
	    
		fullcode1_1=commoncode1_1
		commoncode2_1="wire[31:0]"
		varcode2_1=""
		for i in range(1,self.k+1):
			if(i==self.k):
				varcode2_1+="hash_val_{},hash_val_{}_1;".format(i,i)
			else:
				varcode2_1+="hash_val_{},hash_val_{}_1,".format(i,i)

		fullcode2_1=commoncode2_1+varcode2_1
	      
		commoncode3_1="wire[31:0]a0,c0,"
		varcode3_1=" "
		for i in range(1,self.k+1):
			if(i==self.k):
				varcode3_1+="b0{},port0{};".format(i,i)
			else:
				varcode3_1+="b0{},port0{},".format(i,i)
	  
		fullcode3_1=commoncode3_1+varcode3_1

		commoncode4_1="""
		assign a0  = 32'hdeadbef8;
		assign c0 =  32'hdeadbef8;
		"""

		varcode4_1=" "
		for i in range(1,self.k+1):
			varcode4_1+="assign b0{} = 32'hdeadbef{};\n".format(i,i)
			varcode4_1+="assign port0{} = 32'hdeadbef{};\n".format(i,i)
	  
		fullcode4_1=commoncode4_1+varcode4_1 
	      
		varcode5_1=" "
		for i in range(1,self.k+1):
			varcode5_1+="hash h{}(test_clk,a0[31:0],b0{}[31:0],c0[31:0],ip_pro[71:40],ip_pro[39:8],ip_pro[7:0],hash_val_{}[31:0]);\n".format(i,i,i)
			varcode5_1+="hash_port h{}_1(test_clk,a0[31:0],port0{}[31:0],c0[31:0],{{port_no1,port_no2}},hash_val_{}_1[31:0]);\n".format(i,i,i)
			
		for i in range(1,2*self.k+1):
			varcode5_1+="wire final{};\n".format(i)
			  
		fullcode5_1=varcode5_1
		varcode6_1 = " assign result = final1"
		for i in range(2,2*self.k+1):
			varcode6_1 = varcode6_1 + "&& final{}".format(i)
		varcode6_1 = varcode6_1 + ";\n"
		
		bitsReqd = int(math.ceil(math.log(self.m, 2)))
		for i in range(1,2*self.k+1):
			if(i<=self.k):
				varcode6_1+="bram_bloom0_0_wrm bram_{}(.clock(test_clk),.ram_enable(1'b1),.write_enable(1'b0),.address(hash_val_{}   [{}:0]),.input_data(1'b1),.output_data(final{}));\n".format(i,i,bitsReqd-1,i)
			else:
				varcode6_1+="bram_bloom0_0_wrm bram_{}(.clock(test_clk),.ram_enable(1'b1),.write_enable(1'b0),.address(hash_val_{}_1[{}:0]),.input_data(1'b1),.output_data(final{}));\n".format(i,i-self.k,bitsReqd-1,i)
	  
		fullcode6_1=varcode6_1+"endmodule\n"   

		fullcode_1=fullcode1_1+fullcode2_1+fullcode3_1
		fullcode_2=fullcode4_1+fullcode5_1+fullcode6_1
		fullcode=fullcode_1+fullcode_2
	      
		path=self.srcfiles_loc+"srcfiles/"
		if(os.path.isdir(path) is False):
			os.mkdir(path)		
		

		# open template file for comparator
		template = open(self.template_loc+"bf_packet_match","r")
		tcontent = template.read()
		template.close()

		outputfile = open(path+"bloomfilter_"+self.keyword+".v","w+")
		outputfile.write(fullcode+tcontent)
		outputfile.close()	        
	      
		print("[+] source code for bloom filter generated with {} hash functions".format(self.k))
