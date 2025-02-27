import json
import argparse 

class RulesValidator:
	def __init__(self, rules, srcIpCheck, dstIpCheck, protocolCheck, portCheck):
		self.rules = rules
		self.srcIpCheck = srcIpCheck
		self.dstIpCheck = dstIpCheck
		self.protocolCheck = protocolCheck
		self.portCheck = portCheck

	#To check if src_ips are same(normally or with *)
	def src_ip(self,i,j):
		x = i['src_ip'].split('.')
		y = j['src_ip'].split('.')
		
		if x[0] == '*' or x[0] == y[0]:
			if x[1] == '*' or x[1] == y[1]:
				if x[2] == '*' or x[2] == y[2]:
					if x[3] == '*' or x[3] == y[3]:
						return True
		return False
	
	#To check if dst_ips are same(normally or with *)
	def dst_ip(self,i,j):
		x = i['dst_ip'].split('.')
		y = j['dst_ip'].split('.')
		
		if x[0] == '*' or x[0] == y[0]:
			if x[1] == '*' or x[1] == y[1]:
				if x[2] == '*' or x[2] == y[2]:
					if x[3] == '*' or x[3] == y[3]:
						return True
		return False
	
	#To check if protocols are same
	def protocol(self,i, j):
		if i['protocol'] == j['protocol']:
			return True
		else:
			return False	

	#To check if src_port and dst_port are subsets
	def check_subset(self,i,j):
		if int(i['src_port_min']) <= int(j['src_port_min']):
			if int(i['src_port_max']) >= int(j['src_port_max']):
				if int(i['dst_port_min']) <= int(j['dst_port_min']):
					if int(i['dst_port_max']) >= int(j['dst_port_max']): 
						return True
		return False 
	
	#Remove Contradictions
	#This function returns a list after removing contradictory rules. 
	def findContradiction(self):
		uniqueRules = self.unique_rules()
		length = len(uniqueRules)
		k = []
		
		contra=[]
		for i in range(length):
			for j in range(i+1, length):
				count=0
				if self.srcIpCheck:
					if self.src_ip(uniqueRules[i], uniqueRules[j]):
						count+=1
				
				if self.dstIpCheck:
					if self.dst_ip(uniqueRules[i], uniqueRules[j]):
						count+=1
		    	
				if self.protocolCheck:
					if self.protocol(uniqueRules[i], uniqueRules[j]):
						count+=1    
		    	
				if self.portCheck:
					if self.check_subset(uniqueRules[i], uniqueRules[j]):
						count+=1
				
				if count == 4:
					if uniqueRules[i]['action']!=uniqueRules[j]['action']:
						contra.append((i,j))
						if i not in k:
							k.append(i)
						if j not in k:
							k.append(j)
		
		outdata = []
		for p in range(length):
			if p not in k:
				outdata.append(uniqueRules[p])
		
		if len(outdata) != length:
			print('There are total', len(outdata) , 'rules after removing contradictions')
			print('Below is the list of all rules indices that are correlations of each other')
			print(contra)
		return outdata

	#identify and eliminate subset
	#this functions returns a list of rules after removing the subsets
	def findSubsets(self, outdata):
		l = []
		shadow = []
		
		for i in range(len(outdata)):
			if i in l:
				continue

			for j in range(i+1, len(outdata)):			
				count = 0

				if j in l:
					continue

				if self.srcIpCheck:
					if self.src_ip(outdata[i], outdata[j]):
						count+=1
				
				if self.dstIpCheck:
					if self.dst_ip(outdata[i], outdata[j]):
						count+=1
				
				if self.protocolCheck:
					if self.protocol(outdata[i], outdata[j]):
						count+=1
				
				if self.portCheck:
					if self.check_subset(outdata[i], outdata[j]):
						count+=1
					
				if count == 4:
					if outdata[i]['action'] == outdata[j]['action']:
						shadow.append((i,j))

						if j not in l:
							l.append(j)
		
		finaldata=[]
		for p in range(len(outdata)):
			if p not in l:
				finaldata.append(outdata[p])
		
		if len(finaldata) != len(outdata):
			print('There are total', len(finaldata) , 'rules after removing subsets')
			print('Below is the list of all rule  indices that are simply shadowed')
			print(shadow)
		return finaldata

	#Total number of unique rules in the given json file
	def unique_rules(self):
		l = []
		for j in self.rules:
			if (j in l) is False:
				l.append(j)
		return l


# Use this function below to use this code individually
# if __name__ == "__main__":
# 	parser = argparse.ArgumentParser()
# 	parser.add_argument("-r", help="Path to rule file", required=True)
# 	args = parser.parse_args()

# 	fh = open(args.r, "r")
# 	rules = json.load(fh)["rules"]

# 	rv = RulesValidator(rules, True, True, True, True)

	
