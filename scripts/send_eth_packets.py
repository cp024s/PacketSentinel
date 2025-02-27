from socket import *
import time

import argparse

# Ethernet frame: https://en.wikipedia.org/wiki/Ethernet_frame  
# Destination MAC Address: 6 bytes
# Source MAC Address: 6 bytes
# Ethertype: 2 bytes

# IPV4 frame: https://en.wikipedia.org/wiki/Internet_Protocol_version_4
# Version | IHL | DSCP | ECN | TotalLength: 4 bytes
# ID | Flags | Fragment Offset: 4 bytes
# TTL | Protocol | Header Checksum: 4 bytes
# Source IP address: 4 bytes
# Destination IP address: 4 bytes

# TCP frame: https://en.wikipedia.org/wiki/Transmission_Control_Protocol
# Source Port: 2 bytes
# Destination Port: 2 bytes

interface = "eno1"
s = socket(AF_PACKET, SOCK_RAW)
s.bind((interface, 0))

def combine_fields(dst, src, eth_type, payload):
    assert(len(src) == len(dst) == 6) # 48-bit ethernet addresses
    assert(len(eth_type) == 2) # 16-bit ethernet type
    return dst + src + eth_type + payload

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Packet sender")
	
    parser.add_argument("-i", "--input", metavar="path", required=False, default="feeds/in_eth0.txt", help="Input packets")
    parser.add_argument("-iter", "--iter", metavar="integer", required=False, default=1, help="Number of times each packet is to be sent")
    parser.add_argument("-s", "--sleep", metavar="float", required=False, default=0.5, help="Sleep time in seconds between packets")

    args = parser.parse_args()
    input_file = args.input
    iterations = int(args.iter)
    sleep_time = float(args.sleep)

    lines = []
    frames  = []
    with open(input_file, 'r') as f:
        for line in f:
            hex_string = (line.strip())[4:]
            if hex_string[-1] == '%': hex_string = hex_string[:-1]  # Last line has this for some reason
            frame = bytearray.fromhex(hex_string)
            frame = bytes(frame[:1514])
            frames.append(frame)
    
    for _ in range(iterations):
        for frame in frames:
            print(frame)
            s.send(frame)
            time.sleep(sleep_time)
    

    # i = 0
    # while(True):  
    #     i += 1
    #     print(f"Sent Ethernet packet {i} on eth0")
    #     payload = b"\xFF\xFF" + \
    #                 b"\xFF\xFF\xFF\xFF" + \
    #                 b"\xFF\xFF\xFF\xC9" + \
    #                 b"\xFF\xFF\x15\xA7" + \
    #                 b"\x1C\x7E\xD2\xD7" + \
    #                 b"\x4B\xE4\xD2\x16" + \
    #                 b"\x41\xC8\xFF\xFF" + \
    #                 b"\xFF\xFF" + \
    #                 b"\xdd\x01\x00" + \
    #                 b"\xFF"*20
    #     frame = combine_fields(b"\xFF\xFF\xFF\xFF\xFF\xFF", \
    #         b"\xFF\xFF\xFF\xFF\xFF\xFF", \
    #         b"\xFF\xFF", \
    #         payload)
    #     s.send(frame)        
    #     time.sleep(0.5)
