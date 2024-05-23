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
        StrFixedLenField("result", "y", length=1)
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
    pattern = r"^\s*([LRFB])\s*"
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

    while True:
        s = input('> ')
        if s == "quit":
            break
        print(s)
        try:
            i, ts = p(s, 0, [])
            pkt = Ether(dst='00:04:00:00:00:00', type=0x1234) / Drone(op=ts[0].value)
            pkt = pkt / ' '

            pkt.show()

            resp = srp1(pkt, iface=iface, timeout=5, verbose=False)
            if resp:
                drone_resp = resp[Drone]
                if drone_resp:
                    print(drone_resp.result)
                else:
                    print("Cannot find Drone header in the packet")
            else:
                print("Didn't receive response")
        except Exception as error:
            print(error)

if __name__ == '__main__':
    main()

