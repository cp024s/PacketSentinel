import socket
import time

interface = 'eno1'
sock = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3))
sock.bind((interface, 0))

prev_time = 0
after_time = 0

while True:
    raw_packet, _ = sock.recvfrom(65535)
    after_time = time.time()
    print(after_time - prev_time)
    print(raw_packet.hex())
    prev_time = after_time

