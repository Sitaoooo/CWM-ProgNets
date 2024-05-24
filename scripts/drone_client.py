#!/usr/bin/env python3

import re
from scapy.all import *

class Drone(Packet):
    name = "Drone"
    fields_desc = [
        StrFixedLenField("P", "P", length=1),
        StrFixedLenField("Four", "4", length=1),
        XByteField("version", 0x01),
        StrFixedLenField("op", "F", length=1),
        IntField("positionx", 0),
        IntField("positiony", 0),
        StrFixedLenField("result", "y", length=1),
        IntField("DroneID",0), #support up to 3 drones
        IntField("rej_type",0), #0 is out of bound, 1 is drone in the way
        IntField("drone0_broadcastx",999),
        IntField("drone0_broadcasty",999),
        IntField("drone1_broadcastx",999),
        IntField("drone1_broadcasty",999),
        IntField("drone2_broadcastx",999),
        IntField("drone2_broadcasty",999)
    ]

bind_layers(Ether, Drone, type=0x1234)

class NumParseError(Exception):
    pass

class OpParseError(Exception):
    pass

class Token:
    def __init__(self, type, value=None):
        self.type = type
        self.value = value

def num_parser(s, i, ts):
    pattern = r"^\s*([0-9]+)\s*"
    match = re.match(pattern, s[i:])
    if match:
        ts.append(Token('num', match.group(1)))
        return i + match.end(), ts
    raise NumParseError('Expected number literal.')

def op_parser(s, i, ts):
    pattern = r"^\s*([LRFBQ])\s*"
    match = re.match(pattern, s[i:])
    if match:
        ts.append(Token('op', match.group(1)))
        return i + match.end(), ts
    raise OpParseError("Expected command 'L', 'R', 'F', or 'B'.")

def make_seq(p1, p2):
    def parse(s, i, ts):
        i, ts2 = p1(s, i, ts)
        return p2(s, i, ts2)
    return parse

def get_if():
    ifs = get_if_list()
    iface = "veth0-1"  # Hardcoded for now
    return iface

def main():
    p = op_parser
    iface = "enx0c37965f89ec"
    positionX = 0
    positionY = 0
    
    while True:
        print("F(forward),B(backward),R(rightward),L(leftward),Q(broadcast location)")
        s = input('input operation > ')
        if s == "quit":
            break
        print(s)
        try:
            i, ts = p(s, 0, [])
            pkt = Ether(dst='00:04:00:00:00:00', type=0x1234) / Drone(op=ts[0].value,
                                                                      positionx = positionX,
                                                                      positiony = positionY)
            pkt = pkt / ' '

            #pkt.show()
            print('--------------------')
            resp = srp1(pkt, iface=iface, timeout=5, verbose=False)
            #resp.show()
            
            if resp:
                drone_resp = resp[Drone]
                #drone_resp.show()
                
                if drone_resp:
                    if drone_resp.drone0_broadcastx != 999:
                       print("drone 0 broadcasting location:")
                       print(f" ({drone_resp.drone0_broadcastx}, {drone_resp.drone0_broadcasty})")
                       print('')
                    if drone_resp.drone1_broadcastx != 999:
                       print("drone 1 broadcasting location:")
                       print(f" ({drone_resp.drone1_broadcastx}, {drone_resp.drone1_broadcasty})")
                       print('')
                    if drone_resp.drone2_broadcastx != 999:
                       print("drone 2 broadcasting location:")
                       print(f" ({drone_resp.drone2_broadcastx}, {drone_resp.drone2_broadcasty})")
                       print('')
                    
                    
               	    if drone_resp.result == b'y':
               	        positionX = drone_resp.positionx
               	        positionY = drone_resp.positiony
                        print("Command accepted")
                        print(f"New position: ({positionX}, {positionY})")
                        print('------------------------')
                    else:
                        print("Command rejected")
                        if drone_resp.rej_type == 1:
                            print("other drone in the way")
                        elif drone_resp.rej_type == 0:
                            print("out of bound of the map")
                        print(f"Current position: ({positionX}, {positionY})")
                        print('------------------------')
                else:
                    print("Cannot find Drone header in the packet")
            else:
                print("Didn't receive response")
        except Exception as error:
            print(error)

if __name__ == '__main__':
    main()

