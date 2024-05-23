#include <core.p4>
#include <v1model.p4>

/*
 * Define the headers the program will recognize
 */

/*
 * Standard Ethernet header
 */
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

/*
 * This is a custom protocol header for the drone. We'll use
 * etherType 0x1234 for it (see parser)
 */
const bit<16> Drone_ETYPE = 0x1234;
const bit<8>  Drone_P     = 0x50;   // 'P'
const bit<8>  Drone_4     = 0x34;   // '4'
const bit<8>  Drone_VER   = 0x01;   // v0.1
const bit<8>  Drone_F     = 0x46;   // 'F'
const bit<8>  Drone_B     = 0x42;   // 'B'
const bit<8>  Drone_L     = 0x4C;   // 'L'
const bit<8>  Drone_R     = 0x52;   // 'R'
const bit<8>  Drone_y     = 0x79;   // 'y'
const bit<8>  Drone_n     = 0x6E;   // 'n'

header drone_t {
    bit<8> p;
    bit<8> four;
    bit<8> ver;
    bit<8> op;
    bit<32> positionx;
    bit<32> positiony;
    bit<32> res;
}

/*
 * All headers, used in the program needs to be assembled into a single struct.
 */
struct headers {
    ethernet_t ethernet;
    drone_t drone;
}

/*
 * All metadata, globally used in the program, also needs to be assembled
 * into a single struct.
 */
struct metadata {
    /* In our case it is empty */
}

/*************************************************************************
 ***********************  P A R S E R  ***********************************
 *************************************************************************/
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            Drone_ETYPE : check_Drone;
            default      : accept;
        }
    }

    state check_Drone {
        transition select(packet.lookahead<drone_t>().p,
                          packet.lookahead<drone_t>().four,
                          packet.lookahead<drone_t>().ver) {
            (Drone_P, Drone_4, Drone_VER) : parse_drone;
            default                      : accept;
        }
    }

    state parse_drone {
        packet.extract(hdr.drone);
        transition accept;
    }
}

/*************************************************************************
 ************   C H E C K S U M    V E R I F I C A T I O N   *************
 *************************************************************************/
control MyVerifyChecksum(inout headers hdr,
                         inout metadata meta) {
    apply { }
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action send_back(bit<32> result) {
        bit<48> tmp;
        hdr.drone.res = result;
        tmp = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
        hdr.ethernet.srcAddr = tmp;
        standard_metadata.egress_spec = standard_metadata.ingress_port;
    }

    action operation_forward() {
        send_back(Drone_y);
    }

    action operation_backward() {
        send_back(Drone_y);
    }

    action operation_right() {
        send_back(Drone_y);
    }

    action operation_left() {
        send_back(Drone_y);
    }

    action operation_drop() {
        mark_to_drop(standard_metadata);
    }

    table calculate {
        key = {
            hdr.drone.op : exact;
        }
        actions = {
            operation_forward;
            operation_backward;
            operation_left;
            operation_right;
            operation_drop;
        }
        const default_action = operation_drop();
        const entries = {
            Drone_F : operation_forward();
            Drone_B : operation_backward();
            Drone_L : operation_left();
            Drone_R : operation_right();
        }
    }

    apply {
        if (hdr.drone.isValid()) {
            calculate.apply();
        } else {
            operation_drop();
        }
    }
}

/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

/*************************************************************************
 *************   C H E C K S U M    C O M P U T A T I O N   **************
 *************************************************************************/
control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
 ***********************  D E P A R S E R  *******************************
 *************************************************************************/
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.drone);
    }
}

/*************************************************************************
 ***********************  S W I T C H  **********************************
 *************************************************************************/
V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;

