# Python code to generate in_eth testing packets - This is to be repeated for each ethernet port
import json
import random
import argparse
from array import array
import os

accept_rules = []
reject_rules = []

def read_rules(rules_file):
	rfile_handle = open(rules_file,"r")
	rules = json.load(rfile_handle)["rules"]

	for rule in rules:
		action_type = rule.pop('action')
		if action_type == "ACCEPT":
			accept_rules.append(rule)
		else:
			reject_rules.append(rule)

def random_header_generator(n):
	rand_headers = []

	if n==0:
		return rand_headers
	
	print("Generating random headers")

	for i in range(n):
		src_ip = ".".join(str(random.randint(0, 255)) for _ in range(4))
		dst_ip = ".".join(str(random.randint(0, 255)) for _ in range(4))
		
		protocol = str(random.randint(0, 255))
		
		src_port = str(random.randint(0, 65535))
		dst_port = str(random.randint(0, 65535))

		new_header = {
			'src_ip': src_ip,
			'dst_ip': dst_ip,
			'protocol': protocol,
			'src_port_min': src_port,
			'src_port_max': src_port,
			'dst_port_min': dst_port,
			'dst_port_max': dst_port
		}

		rand_headers.append(new_header)

	return rand_headers

def unsafe_header_generator(n):	
	if n==0:
		rand_headers = []
		return rand_headers
	
	print("Generating unsafe headers")

	# necessary for testing
	assert len(accept_rules) != 0, "/**** No accept rules provided ****/"

	rand_headers = random.choices(accept_rules, k=n)
	return rand_headers

def safe_header_generator(n):
	print("Generating safe headers")

	# not necessary for testing
	if len(reject_rules) == 0:
		print("/**** No reject rules provided ****/")
		rand_headers = []
		return rand_headers

	rand_headers = random.choices(reject_rules, k=n)
	return rand_headers

def packet_generator(header): 
	# Header head0;
	# head0.protocol = eth0frame.frame[5][31:24]; //[23];
	# head0.srcip = {eth0frame.frame[6][31:16], eth0frame.frame[7][15:0]}; //[26:29];
	# head0.dstip = {eth0frame.frame[7][31:16], eth0frame.frame[8][15:0]}; //[30:33];
	# head0.srcport = eth0frame.frame[8][31:16]; //[34:35];
	# head0.dstport = eth0frame.frame[9][15:0]; //[36:37];

	# 	typedef struct {
	# 	Bit#(16) len;
	# 	Vector#(`FrameSizeWord, Bit#(32)) frame;
	# } EthFrame deriving (Bits, FShow, Eq);
	max_payload_size = EthMTUSize - EthHeaderSize - EthFCSSize
	# payload_size = random.randint(1, max_payload_size) & 0xFFFF
	payload_size = max_payload_size & 0xFFFF ## testing purpose

	data_size = bytearray(payload_size.to_bytes(2, 'big'))
	data_size = data_size[0:2] # take 2 bytes
	data_size_array = array('B', data_size)

	rand_packet = random.randint(0, (1 << (FrameSize * 8)) - 1)
	rand_packet = (1 << (FrameSize * 8)) - 1 ## testing purpose

    # Extract the bytes from the random number
	byte_str = rand_packet.to_bytes(FrameSize, 'big')
	byte_array = bytearray(byte_str)#, byteorder='big')
	
	# Correspondingly done in bluespec
	byte_array[23] = int(header['protocol'])
	byte_array[26:30] = [int(c) for c in header['src_ip'].split('.')]
	byte_array[30:34] = [int(c) for c in header['dst_ip'].split('.')]
	byte_array[34:36] = bytearray(int(header['src_port_min']).to_bytes(2, 'big'))
	byte_array[36:38] = bytearray(int(header['dst_port_min']).to_bytes(2, 'big'))

	byte_array_as_array = array('B', byte_array)  # Create array.array with byte elements
	mod_packet = int.from_bytes(data_size_array + byte_array_as_array, 'big')
	hex_string = '{:x}'.format(mod_packet)
	while len(hex_string) < FrameSize*2+4: # Size of len is 16bits
		hex_string = "0"+hex_string
	return hex_string

if __name__ == "__main__":
	parser = argparse.ArgumentParser(description="Process arguments for packet generation")
	
	parser.add_argument("rules_file", help="Location of the rules file")
	parser.add_argument("packet_feed_folder", help="Location of the packet feed folder")
	parser.add_argument("--num_safe", type=int, default=0, help="Number of safe packets")
	parser.add_argument("--num_unsafe", type=int, default=0, help="Number of unsafe packets")
	parser.add_argument("--num_random", type=int, default=0, help="Number of random packets")
	parser.add_argument("--EthHeaderSize", type=int, default=0, help="EthHeader size")
	parser.add_argument("--EthMTUSize", type=int, default=0, help="EthMTU size")
	parser.add_argument("--EthFCSSize", type=int, default=0, help="EthFCS size")
	parser.add_argument("--FrameSize", type=int, default=0, help="Frame size")
	parser.add_argument("--EthID", type=int, default=0, help="Ethernet ID")

	args = parser.parse_args()

	EthHeaderSize = args.EthHeaderSize
	EthMTUSize = args.EthMTUSize
	EthFCSSize = args.EthFCSSize
	FrameSize = args.FrameSize
	FrameSizeWord = FrameSize // 4
	EthID = args.EthID
	
	assert os.path.exists(args.packet_feed_folder), "Packet feed folder doesn't exist"
	in_file = args.packet_feed_folder + "/in_eth" + str(EthID) + ".txt"

	read_rules(args.rules_file)

	all_headers = []
	all_headers.extend(safe_header_generator(args.num_safe))
	all_headers.extend(unsafe_header_generator(args.num_unsafe))
	all_headers.extend(random_header_generator(args.num_random))

	## can be randomised here

	fh = open(in_file, "w")
	for l in range(len(all_headers)):
		header = all_headers[l]
		pkt = packet_generator(header)

		## write packet into file
		fh.write(pkt)
		if l != len(all_headers)-1:
			fh.write("\n")

print("Packet generation completed")
