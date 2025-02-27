## Copy of original classifier.py

import os
import argparse
# from scripts import memModels, rulesValidator, templates
# Import specific names from the modules if needed
from scripts.templates import *
from scripts.memModels import *
from scripts.rulesValidator import *


templates_loc = "templates/"
HEADER_WIDTH = 8
PORT_WIDTH = 16

class Classifier:
	def __init__(self, argsr, argsf, argsu, argso):
		#+++++++++++++++++++++++
		# Input files
		#+++++++++++++++++++++++
		rules_file = argsr 
		fpga_constraints_file = argsf
		user_constraints_file = argsu
		self.templates_loc = templates_loc

		#+++++++++++++++++++++++
		# Output file locations
		#+++++++++++++++++++++++	
		self.memfiles_loc = argso+"memfiles/"
		self.srcfiles_loc = argso+"srcfiles/"

		if not os.path.isdir(argso):
			os.makedirs(argso)
		
		if not os.path.isdir(self.memfiles_loc):
			os.makedirs(self.memfiles_loc)
		
		if not os.path.isdir(self.srcfiles_loc):
			os.makedirs(self.srcfiles_loc)

		#+++++++++++++++++++++++
		# Parse the inputs
		#+++++++++++++++++++++++
		rfile_handle = open(rules_file,"r")
		self.rules = json.load(rfile_handle)["rules"]

		ffile_handle = open(fpga_constraints_file,"r")
		self.fpga_constraints = json.load(ffile_handle)["fpga_constraints"]

		ufile_handle = open(user_constraints_file,"r")
		self.user_constraints = json.load(ufile_handle)["user_constraints"]	
		
		is_ipv6 = (self.user_constraints["ipv6"]=="yes")
		if(not is_ipv6):
			self.header_width = HEADER_WIDTH
			self.port_width = PORT_WIDTH
			
		# false positives accepted?
		self.fp_accepted = float(self.user_constraints["max_false_positive_rate"])
		self.parallelBFRequired = float(self.user_constraints["parallelBFRequired"]=="yes")
	
	def validateRules(self):
		print("Validating Rules...")
		rv = RulesValidator(self.rules, self.user_constraints["srcIpCheck"]=="yes", self.user_constraints["dstIpCheck"]=="yes", self.user_constraints["protocolCheck"]=="yes", self.user_constraints["portCheck"]=="yes")
		self.rules = rv.findSubsets(rv.findContradiction())		

	#+++++++++++++++++++++++
	# analyser inputs
	#+++++++++++++++++++++++

	def classify(self):
		# number of rules
		no_of_rules = len(self.rules) 
		print("No. of rules:", no_of_rules)

		whitelist_rules = []
		for i in range(no_of_rules):
			if(self.rules[i]["action"] == "ACCEPT"):
				whitelist_rules.append(self.rules[i])
				
		self.rules = whitelist_rules
		self.validateRules()
		no_of_rules = len(self.rules)
		self.useComparator = self.user_constraints["useComparator"]=="yes"

		assert no_of_rules!=0, "Insufficient number of rules to generate firewall"
		
		rulesWithRangeMatching=[]
		rulesWithOutRangeMatching=[]
		
		for i in range(no_of_rules):
			if((self.rules[i]["src_port_max"] == self.rules[i]["src_port_min"]) & 
				(self.rules[i]["dst_port_max"] == self.rules[i]["dst_port_min"])):
				rulesWithOutRangeMatching.append(self.rules[i])
			else:
				rulesWithRangeMatching.append(self.rules[i])

		no_of_rules = len(rulesWithRangeMatching)
		if no_of_rules != 0:
			print("No. of rules with range matching:", no_of_rules)
			
		rmNeeded=False
		wrmNeeded=False	
		####### range matching not required?
		if(len(rulesWithRangeMatching) > 0):
			rmNeeded = True
			self.FSBVTop(rulesWithRangeMatching, rangeMatching = True)
		    
		if(len(rulesWithOutRangeMatching) > 0):
			wrmNeeded = True
			if(self.fp_accepted > 0):
				self.BFTop(rulesWithOutRangeMatching, self.fp_accepted)
			else:
				self.FSBVTop(rulesWithOutRangeMatching, rangeMatching = False)
			
		W = 9*self.header_width	

		# Consolidate results from the range matching rules and without range matching
		template_file = self.templates_loc+"topmodule" 
		tm = TopModule(template_file, self.srcfiles_loc, W, self.W1, wrmNeeded, rmNeeded)
		tm.generateSource()	

		# TODO - Add support to generate tb.v from template
	
	def FSBV_DRAM(self, ruleSet, i, rangeMatching):
		stride = int(self.fpga_constraints["no_inp_to_LUTS"])
		dram_depth = int(self.fpga_constraints["dram_depth"])
		maxRules = int(self.fpga_constraints["DRAM_maxRules"])
	    
		if (maxRules != -1):
			startIndex = i*maxRules
			endIndex = (i+1)*maxRules 
		    
			if (endIndex > len(ruleSet)): 
				endIndex = len(ruleSet)
			else:
				startIndex = 0
				endIndex = len(ruleSet)
		
			ruleSet = ruleSet[startIndex : endIndex]
		
		no_of_rules = len(ruleSet)
		if(rangeMatching):
			memfilespath = self.memfiles_loc+"ipprot_module"+str(i)+"_rm/"		
		else:
			memfilespath = self.memfiles_loc+"ipprot_module"+str(i)+"_wrm/"
			
		fsbv = FSBV(self.header_width, stride, getIPAndProtocolLists(ruleSet), memfilespath)
		## generate FSBV memory files
		fsbv.generateMemory()
	
		if(rangeMatching):
			keyword1 = str(i)+"_rm"
		else:
			keyword1 = str(i)+"_wrm"
		
		W = 9*self.header_width # 4 fields each for src ip and dst ip, and one field for protocol
		keyword="ipprot"
		
		## Generate DRAM files
		template_file = self.templates_loc+"dram"
		dram = DRAM(template_file, self.srcfiles_loc, memfilespath, W, stride, dram_depth, no_of_rules, keyword, keyword1)
		dram.generateSource()

		## Generate code to match ip and protocol fields
		template_file = self.templates_loc+"ipprot_match"
		    
		ipprot_match = IPPROT_MATCH(template_file, self.srcfiles_loc, W, stride, no_of_rules, True,keyword1)
		ipprot_match.generateSource()
		
		self.W1 = self.port_width
		while(self.W1%stride != 0):
			self.W1 = self.W1 +1
		
		if(rangeMatching):
			if(self.useComparator):
				portnum = 1
				template_loc = self.templates_loc	
				srcport_match = PORT_MATCH_WITH_RANGES_COMP(template_loc, self.srcfiles_loc, stride, no_of_rules, portnum, getSrcPortListWithRanges(ruleSet),keyword1, self.port_width)
				srcport_match.generateSource()
				portnum = 2
				template_loc = self.templates_loc
				dstport_match = PORT_MATCH_WITH_RANGES_COMP(template_loc, self.srcfiles_loc, stride, no_of_rules, portnum, getDstPortListWithRanges(ruleSet),keyword1, self.port_width)
				dstport_match.generateSource()
			else:		
				memfilespath = self.memfiles_loc+"srcport_module"+str(i)+"_rm/"
			fsbv_sport = FSBVplusNAF(self.port_width, stride, getSrcPortListWithRanges(ruleSet),memfilespath)
			[ctr, sign_f] = fsbv_sport.generateMemory()
			keyword="srcport"
			template_file = self.templates_loc+"dram"
			output_width = ctr[-1]
			dram = DRAM(template_file, self.srcfiles_loc, memfilespath, self.W1, stride, dram_depth, output_width,keyword, keyword1)
			dram.generateSource()		
			
			## Generate code for port matching
			portnum = 1	
#			template_file = self.templates_loc+"port_match_noranges"
			template_file = self.templates_loc+"port_match_ranges"			
			srcport_match = PORT_MATCH_WITH_RANGES(template_file, self.srcfiles_loc, self.W1, stride, no_of_rules, portnum, True, keyword1, ctr, sign_f)
			srcport_match.generateSource()			


			## Use FSBV for dst port
			memfilespath = self.memfiles_loc+"dstport_module"+str(i)+"_rm/"
			fsbv_dport = FSBVplusNAF(self.port_width, stride, getDstPortListWithRanges(ruleSet), memfilespath)
			[ctr, sign_f] = fsbv_dport.generateMemory()
				
			portnum=2
			keyword="dstport"

			## Generate DRAM files
			template_file = self.templates_loc+"dram"
			output_width = ctr[-1]
			dram = DRAM(template_file, self.srcfiles_loc, memfilespath, self.W1, stride, dram_depth, output_width,keyword, keyword1)
			dram.generateSource()
					
			## Generate code for port matching
			template_file = self.templates_loc+"port_match_ranges"			
			dstport_match = PORT_MATCH_WITH_RANGES(template_file, self.srcfiles_loc, self.W1, stride, no_of_rules, portnum, True, keyword1, ctr, sign_f)
			dstport_match.generateSource()								
			
		else:
			memfilespath = self.memfiles_loc+"srcport_module"+str(i)+"_wrm/"
			fsbv_sport = FSBV(self.port_width, stride, getSrcPortList(ruleSet), memfilespath)
			fsbv_sport.generateMemory()
			keyword="srcport"
			template_file = self.templates_loc+"dram"		
			dram = DRAM(template_file, self.srcfiles_loc, memfilespath, self.W1, stride, dram_depth, no_of_rules,keyword, keyword1)
			dram.generateSource()		
			
			## Generate code for port matching
			portnum = 1	
			template_file = self.templates_loc+"port_match_noranges"
			srcport_match = PORT_MATCH(template_file, self.srcfiles_loc, self.W1, stride, no_of_rules,portnum,True,keyword1)
			srcport_match.generateSource()
			## Use FSBV for dst port
			memfilespath = self.memfiles_loc+"dstport_module"+str(i)+"_wrm/"
			fsbv_dport = FSBV(self.port_width, stride, getDstPortList(ruleSet), memfilespath)
			fsbv_dport.generateMemory()
			portnum=2
			keyword="dstport"

			## Generate DRAM files
			template_file = self.templates_loc+"dram"
			dram = DRAM(template_file, self.srcfiles_loc, memfilespath, self.W1, stride, dram_depth, no_of_rules,keyword, keyword1)
			dram.generateSource()
					
			## Generate code for port matching
			template_file = self.templates_loc+"port_match_noranges"
			dstport_match = PORT_MATCH(template_file, self.srcfiles_loc, self.W1, stride, no_of_rules,portnum,True,keyword1)
			dstport_match.generateSource()							
		
		## Generate the code for final matching.
		template_file = self.templates_loc+"final_match"
		fm = FinalMatch(template_file, self.srcfiles_loc, W, self.W1, stride, no_of_rules, keyword1)
		fm.generateSource()

	def FSBV_BRAM(self, ruleSet, i, rangeMatching):
		stride = int(self.fpga_constraints["bram_input_size"])
		bram_width = int(self.fpga_constraints["bram_width"])
		maxRules = int(self.fpga_constraints["BRAM_maxRules"])
	    
		if(maxRules != -1):
			startIndex = i*maxRules
			endIndex = (i+1)*maxRules 
			if(endIndex > len(ruleSet)): 
				endIndex = len(ruleSet)
			else:
				startIndex = 0
				endIndex = len(ruleSet)
			
		ruleSet = ruleSet[startIndex : endIndex]
		no_of_rules = len(ruleSet)
		if(rangeMatching):
			memfilespath = self.memfiles_loc+"ipprot_module"+str(i)+"_rm/"
		else:
			memfilespath = self.memfiles_loc+"ipprot_module"+str(i)+"_wrm/"		
		fsbv = FSBV(self.header_width, stride, getIPAndProtocolLists(ruleSet), memfilespath)
		## generate FSBV memory files
		fsbv.generateMemory()
		
		if(rangeMatching):
			keyword1 = str(i)+"_rm"
		else:
			keyword1 = str(i)+"_wrm"
		
		W = 9*self.header_width # 4 fields each for src ip and dst ip, and one field for protocol
		keyword="ipprot"

		## Generate BRAM files
		template_file = self.templates_loc+"bram"	

			
		bram = BRAM(template_file, self.srcfiles_loc, memfilespath, W, stride, no_of_rules, keyword, keyword1)
		bram.generateSource()
					
		## Generate code to match ip and protocol fields
		template_file = self.templates_loc+"ipprot_match"
		ipprot_match = IPPROT_MATCH(template_file, self.srcfiles_loc, W, stride, no_of_rules, False,keyword1)
		ipprot_match.generateSource()
		
		# self.W1 = self.port_width+2 					
		if(rangeMatching):
			if(self.useComparator):
				portnum = 1
				template_loc = self.templates_loc	
				srcport_match = PORT_MATCH_WITH_RANGES_COMP(template_loc, self.srcfiles_loc, stride, no_of_rules, portnum, getSrcPortListWithRanges(ruleSet),keyword1, self.port_width)
				srcport_match.generateSource()
				self.W1 = self.port_width
				while(self.W1%stride != 0):
					self.W1 = self.W1 +1
					
				portnum = 2
				template_loc = self.templates_loc	
				dstport_match = PORT_MATCH_WITH_RANGES_COMP(template_loc, self.srcfiles_loc, stride, no_of_rules, portnum, getDstPortListWithRanges(ruleSet),keyword1, self.port_width)
				dstport_match.generateSource()			
			else:
				memfilespath = self.memfiles_loc+"srcport_module"+str(i)+"_rm/"
			## Use FSBV for src port
			portList = getSrcPortListWithRanges(ruleSet)
			fsbv_sport = FSBVplusNAF(self.port_width, stride,portList , memfilespath)
			[ctr, sign_f] = fsbv_sport.generateMemory()
			
			self.W1 = self.port_width
			while(self.W1%stride != 0):
				self.W1 = self.W1 +1
         		    
			## Generate BRAM file
			template_file = self.templates_loc+"bram"
			bram_width = ctr[-1]
			bram = BRAM(template_file, self.srcfiles_loc, memfilespath, self.W1, stride, bram_width, "srcport", keyword1)
			bram.generateSource()			
			
			## Generate code for port matching
			portnum = 1
			template_file = self.templates_loc+"port_match_ranges"
			srcport_match = PORT_MATCH_WITH_RANGES(template_file, self.srcfiles_loc, self.W1, stride, no_of_rules, portnum,False, keyword1, ctr, sign_f)
			srcport_match.generateSource()
			
			
			## Use FSBV for dst port
			memfilespath = self.memfiles_loc+"dstport_module"+str(i)+"_rm/"
			fsbv_dport = FSBVplusNAF(self.port_width, stride, getDstPortListWithRanges(ruleSet),memfilespath )
			#print("DONE..")
			[ctr, sign_f] = fsbv_dport.generateMemory()
				
			
			portnum=2
			keyword="dstport"
			
			## Generate BRAM files
			template_file = self.templates_loc+"bram"		
			bram_width = ctr[-1]
			bram = BRAM(template_file, self.srcfiles_loc, memfilespath, self.W1, stride, bram_width, "dstport",keyword1)
			bram.generateSource()			
					
			## Generate code for port matching
			template_file = self.templates_loc+"port_match_ranges"
			dstport_match = PORT_MATCH_WITH_RANGES(template_file, self.srcfiles_loc, self.W1, stride, no_of_rules, portnum, False, keyword1, ctr, sign_f)
			dstport_match.generateSource()
			
		else:
			memfilespath = self.memfiles_loc+"srcport_module"+str(i)+"_wrm/"
			portList = getSrcPortList(ruleSet)
			fsbv_sport = FSBV(self.port_width, stride, portList, memfilespath)
			fsbv_sport.generateMemory()
			
			self.W1 = self.port_width
			while(self.W1%stride != 0):
				self.W1 = self.W1 +1
			
			## Generate BRAM file
			template_file = self.templates_loc+"bram"		
			bram = BRAM(template_file, self.srcfiles_loc, memfilespath, self.W1, stride, no_of_rules, "srcport", keyword1)
			bram.generateSource()			
			
			## Generate code for port matching
			portnum = 1
			template_file = self.templates_loc+"port_match_noranges"
			srcport_match = PORT_MATCH(template_file, self.srcfiles_loc, self.W1, stride, no_of_rules, portnum,False, keyword1)
			srcport_match.generateSource()		
			
			## Use FSBV for dst port
			memfilespath = self.memfiles_loc+"dstport_module"+str(i)+"_wrm/"
			fsbv_dport = FSBV(self.port_width, stride, getDstPortList(ruleSet), memfilespath)
			fsbv_dport.generateMemory()

			portnum=2
			keyword="dstport"
			
			## Generate BRAM files
			template_file = self.templates_loc+"bram"		
			bram = BRAM(template_file, self.srcfiles_loc, memfilespath, self.W1, stride, no_of_rules, "dstport",keyword1)
			bram.generateSource()			
					
			## Generate code for port matching
			template_file = self.templates_loc+"port_match_noranges"
			dstport_match = PORT_MATCH(template_file, self.srcfiles_loc, self.W1, stride, no_of_rules,portnum,False, keyword1)
			dstport_match.generateSource()	
		
		## Generate the code for final matching.
		template_file = self.templates_loc+"final_match"
		fm = FinalMatch(template_file, self.srcfiles_loc, W, self.W1, stride, no_of_rules, keyword1)
		fm.generateSource()
	
	def FSBVTop(self, ruleSet, rangeMatching):
		print("Generating FSBV...")
		no_of_rules = len(ruleSet) 
		#print("No. of rules without range matching:"+str(no_of_rules))
		useDRAM = (self.user_constraints["useDRAM"]=="yes")
		DRAM_maxRules = int(self.fpga_constraints["DRAM_maxRules"])
		BRAM_maxRules = int(self.fpga_constraints["BRAM_maxRules"])
		if(useDRAM):
			if(DRAM_maxRules != -1):
				noOfInstances = int(math.ceil(no_of_rules/float(DRAM_maxRules)))
			else:
				noOfInstances = 1
				
			for i in range(noOfInstances):
				self.FSBV_DRAM(ruleSet, i, rangeMatching)
		else:
			max_brams = int(self.fpga_constraints["max_BRAMs"])
			if(BRAM_maxRules != -1):
				noOfInstances = int(math.ceil(no_of_rules/float(BRAM_maxRules)))
				# ASSUME THAT RAM_maxRules is less BRAM Width.
				if(noOfInstances > 0.8*max_brams):
					raise InSufficientBRAMsError
			else:
				noOfInstances = 1
				if(int(math.ceil(no_of_rules/float(bram_width))) > 0.8*max_brams):
					raise InSufficientBRAMsError; 
				
			for i in range(noOfInstances):
				self.FSBV_BRAM(ruleSet, i, rangeMatching)
		
		W = 9*self.header_width
		stride = int(self.fpga_constraints["no_inp_to_LUTS"]);
		# Consolidate results from the splitted "final_match" modules.
		template_file = self.templates_loc+"consolidator"                	
		cns = Consolidator(template_file, self.srcfiles_loc, W, self.W1, stride, noOfInstances, rangeMatching)
		cns.generateSource()
	
	def BFTop(self, ruleSet, fp_accepted):
		print("Generating Bloom Filter...")
		no_of_rules=len(ruleSet)
		memfilespath = self.memfiles_loc+"bloomfilter_wrm/"
		
		rangeMatching = False # as of now range matching is False for bloom filter.
		#print("No. of rules:"+str(no_of_rules))
		srcPortList = getSrcPortList(ruleSet)
		dstPortList = getDstPortList(ruleSet)
		ipProtocolLists = getIPAndProtocolLists(ruleSet)
		bloom1=BloomFilter(no_of_rules, fp_accepted, ipProtocolLists, srcPortList, dstPortList, memfilespath)
		[m, k] = bloom1.generateMemory()
		print("Memory required:", m)
		print("Hash count:", k)
		self.W1 = 16 ####################### Added based on class BF_PACKET_MATCH - if optim required then can be modified

		if(self.parallelBFRequired):
			requiredMem = 2*k*m 
			bramSize = bram_width* (2**bram_input_size)
			if(requiredMem > bramSize):
				noOfInstances = int(math.ceil(requiredMem/float(bramSize)))
				# ASSUME THAT RAM_maxRules is less BRAM Width.
				if(noOfInstances > 0.8*max_brams):
					raise InSufficientBRAMsError
			else:
				noOfInstances = 1 
		else: 
			noOfInstances = 1
		
		self.BF_BRAM(noOfInstances, rangeMatching, m, k)
		template_file = self.templates_loc+"consolidator"                			
		W = 9*self.header_width
		stride=1
		cns = Consolidator(template_file, self.srcfiles_loc, W, self.W1, stride, noOfInstances, rangeMatching)
		cns.generateSource()
				        		
        		
	def BF_BRAM(self, noOfInstances, rangeMatching, m, k):
		if(rangeMatching==False):
			## Generate BRAM files
			template_file = self.templates_loc+"bram_bf"	
			stride = int(math.ceil(math.log(m,2)))
			#print("bloom filter size :" + str(m))
			
			for i in range(noOfInstances):
				keyword1 = str(i)+"_wrm"
				bram = BRAM(template_file, self.srcfiles_loc, self.memfiles_loc+"bloomfilter_wrm/", stride, stride, int(1), "bloom", keyword1)
				bram.generateSource()		

				bloomCode = BF_PACKET_MATCH(self.templates_loc, self.srcfiles_loc, m, k, keyword1)
				bloomCode.generateSource()	

class InSufficientBRAMsError(Exception):
    """Exception raised for errors in the input salary.

    Attributes:
        message -- explanation of the error
    """

    def __init__(self, message="Insufficient # of BRAMs"):
        self.message = message
        super().__init__(self.message)
	
def getSrcPortList(rules):
	srcPortList = []	
	no_of_rules = len(rules)
	for i in range(no_of_rules):
		srcPortList.append(rules[i]["src_port_min"])
	
	return [srcPortList]
	
def getDstPortList(rules):
	dstPortList = []	
	no_of_rules = len(rules)
	for i in range(no_of_rules):
		dstPortList.append(rules[i]["dst_port_min"])
	
	return [dstPortList]	

	
def getIPAndProtocolLists(rules):
	# 1 Rule is represented by 9 Decimal Values 4 each of Src IP and Dst IP and 1 of Protocol field
	# The loop converts decimal value of Src IP, Dst IP, Protocol from header fields into binary values and merges them to produce 72 bit rule
	src_ip_field0 = []
	src_ip_field1 = []
	src_ip_field2 = []
	src_ip_field3 = []
	dst_ip_field0 = []
	dst_ip_field1 = []
	dst_ip_field2 = []
	dst_ip_field3 = []
	protocol = []
	no_of_rules = len(rules)
	for i in range(no_of_rules):		
		src_ip_fields = rules[i]["src_ip"].split(".")
		src_ip_field0.append(src_ip_fields[0])
		src_ip_field1.append(src_ip_fields[1])
		src_ip_field2.append(src_ip_fields[2])
		src_ip_field3.append(src_ip_fields[3])

		dst_ip_fields = rules[i]["dst_ip"].split(".")
		dst_ip_field0.append(dst_ip_fields[0])
		dst_ip_field1.append(dst_ip_fields[1])
		dst_ip_field2.append(dst_ip_fields[2])
		dst_ip_field3.append(dst_ip_fields[3])

		protocol.append(rules[i]["protocol"])
	
	return [src_ip_field0,src_ip_field1,src_ip_field2,src_ip_field3,dst_ip_field0,dst_ip_field1,dst_ip_field2,dst_ip_field3,protocol]

if __name__ == "__main__":
	## getting inputs
	parser = argparse.ArgumentParser()
	parser.add_argument("-r", help="Path to rule file", required=True)
	parser.add_argument("-f", help="Path to FPGA constraints file",required=True)
	parser.add_argument("-u", help="Path to user constraints file",required=True)
	parser.add_argument("-o", help="Path to output folders",required=True)
	args = parser.parse_args()

	if args.o[-1] != '/':
			args.o = args.o + '/'
	
	c = Classifier(args.r, args.f, args.u, args.o)
	c.classify()
	# print("Verilog files generated inside", args.o)


