import random
import sys

numberOfRules = int(sys.argv[1])
print("Generating "+str(numberOfRules)+" rules")

f = open("rulesNew1.json","w")
buf = "{\"rules\":["
for i in range(numberOfRules): 
    # ipv4 header sizes are used
    src_ip_1 = random.randint(0,255)
    src_ip_2 = random.randint(0,255)
    src_ip_3 = random.randint(0,255)
    src_ip_4 = random.randint(0,255)

    dst_ip_1 = random.randint(0,255)
    dst_ip_2 = random.randint(0,255)
    dst_ip_3 = random.randint(0,255)
    dst_ip_4 = random.randint(0,255)
    
    protocol = random.randint(0,255)

    srcport_min = random.randint(0,65535)
    srcport_max = random.randint(srcport_min,65535)
    dstport_min = random.randint(0,65535)    
    dstport_max = random.randint(dstport_min,65535)    
    

    newline = "{\"src_ip\":\"" + str(src_ip_1) +"." + str(src_ip_2) + "." + str(src_ip_3) + "." + str(src_ip_4) + "\"," + "\"dst_ip\":\""+ str(dst_ip_1) +"."+ str(dst_ip_2) + "." + str(dst_ip_3) + "." + str(dst_ip_4) + "\",\"protocol\":\""+str(protocol)+"\",\"src_port_min\":\""+str(srcport_min)+"\",\"src_port_max\":\""+str(srcport_max)+"\","+"\"dst_port_min\":\""+str(dstport_min)+"\",\"dst_port_max\":\""+str(dstport_max)+"\""
    
    if(random.randint(0,1)==0):    
        action = ",\"action\":\"ACCEPT\"}"
    else:
        action = ",\"action\":\"REJECT\"}"
    newline = newline+action
    
    if(i==numberOfRules-1):
    	buf = buf+newline+"\n"
    else:
    	buf = buf+newline+",\n"

buf = buf + "]}\n"
f.write(buf)
f.close()
