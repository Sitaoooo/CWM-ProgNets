#!/usr/bin/env python

from scapy.all import Ether, IP, sendp, get_if_hwaddr, get_if_list, TCP, Raw, UDP
import sys
import random, string

def randomword(length):
    return ''.join(random.choice(string.ascii_lowercase) for i in range(length))

def send_random_traffic(num_packets, interface, src_ip, dst_ip):
    dst_mac = "00:00:00:00:00:01"
    src_mac = "CA:FE:CA:FE:CA:FE"
    port = 5555
    total_pkts = 0
    
    for i in range(num_packets):
        data = randomword(512)
        p = Ether(dst=dst_mac, src=src_mac) / IP(dst=dst_ip, src=src_ip) / TCP(sport=50000, dport=port) / Raw(load=data)
        sendp(p, iface=interface, inter=0.01)
        total_pkts += 1

        # If you want to see the contents of the packet, uncomment the line below
        # print(p.show())
    
    print("Sent %s packets in total" % total_pkts)

if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: python send.py number_of_packets interface_name src_ip_address dst_ip_address")
        sys.exit(1)
    else:
        num_packets = sys.argv[1]
        interface = sys.argv[2]
        src_ip = sys.argv[3]
        dst_ip = sys.argv[4]
        send_random_traffic(int(num_packets), interface, src_ip, dst_ip)
