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
const bit<8>  Drone_Q     = 0x51;   // 'Q'
const bit<8>  Drone_y     = 0x79;   // 'y'
const bit<8>  Drone_n     = 0x6E;   // 'n'
const bit<32> drone_0     = 1;   // for bitwise operation b...1
const bit<32> drone_1     = 2;                 // b....10
const bit<32> drone_2     = 4;                 //b....100

header drone_t {
    bit<8> p;
    bit<8> four;
    bit<8> ver;
    bit<8> op;
    bit<32> positionx;
    bit<32> positiony;
    bit<8> res;
    bit<32> drone_id;
    bit<32> rej_type;
    bit<32> drone0_broadcastx;
    bit<32> drone0_broadcasty;
    bit<32> drone1_broadcastx;
    bit<32> drone1_broadcasty;
    bit<32> drone2_broadcastx;
    bit<32> drone2_broadcasty;
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
/* Register to store the positions of drones */
register<bit<32>>(3) drone_positions_x;
register<bit<32>>(3) drone_positions_y;
register<bit<32>>(3) inbox;

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action send_back(bit<8> result) {
        bit<48> tmp;
        hdr.drone.res = result;
        tmp = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
        hdr.ethernet.srcAddr = tmp;
        standard_metadata.egress_spec = standard_metadata.ingress_port;
    }
    
    action update_position(bit<32> drone_id, bit<32> posx, bit<32> posy) {
        drone_positions_x.write(drone_id, posx);
        drone_positions_y.write(drone_id, posy);
        hdr.drone.positionx = posx;
        hdr.drone.positiony = posy;
    }
    
    
    
    
    action check_collision(bit<32> new_posx, bit<32> new_posy) {
        bit<32> i = 0;
        bit<32> stored_posx;
        bit<32> stored_posy;
        drone_positions_x.write(2, 1); //drone2 at 1,1
        drone_positions_y.write(2, 1);
        drone_positions_x.write(1, 2);  //drone 1 at 2,5
        drone_positions_y.write(1, 5);
        
        //check drone 0
        drone_positions_x.read(stored_posx, i);
        drone_positions_y.read(stored_posy, i);
        if (new_posx < 10 && new_posy < 10 && new_posx >= 0 && new_posy >= 0){
            hdr.drone.res = Drone_y;
            if (hdr.drone.drone_id != i){
            	if (stored_posx == new_posx && stored_posy == new_posy) {
               		hdr.drone.res = Drone_n;
               		hdr.drone.rej_type = 1;}}}
        else{
        hdr.drone.res = Drone_n;
        }
        
        
        //check drone1
        i = 1;
        drone_positions_x.read(stored_posx, i);
        drone_positions_y.read(stored_posy, i);
        if (hdr.drone.res == Drone_y){
         if (new_posx < 10 && new_posy < 10 && new_posx >= 0 && new_posy >= 0){
            hdr.drone.res = Drone_y;
            if (hdr.drone.drone_id != i){
            	if (stored_posx == new_posx && stored_posy == new_posy) {
               		hdr.drone.res = Drone_n;
               		hdr.drone.rej_type = 1;}}}
        else{
        hdr.drone.res = Drone_n;
        }}
        
        
        //check drone2
        i = 2;
        drone_positions_x.read(stored_posx, i);
        drone_positions_y.read(stored_posy, i);
        if (hdr.drone.res == Drone_y){
         if (new_posx < 10 && new_posy < 10 && new_posx >= 0 && new_posy >= 0){
            hdr.drone.res = Drone_y;
            if (hdr.drone.drone_id != i){
            	if (stored_posx == new_posx && stored_posy == new_posy) {
               		hdr.drone.res = Drone_n;
               		hdr.drone.rej_type = 1;}}}
        else{
        hdr.drone.res = Drone_n;
        }}
        }
    
    
   
    
    
    
    
    
    
    action received_broadcast(){
        bit<32> value0;
        bit<32> value1;
        bit<32> value2;
        inbox.read(value0,0);
        inbox.read(value1,1);
        inbox.read(value2,2);
        
        bit<32> drone0_x;
        bit<32> drone0_y;
        bit<32> drone1_x;
        bit<32> drone1_y;
        bit<32> drone2_x;
        bit<32> drone2_y;
        
        
        drone_positions_x.read(drone0_x,0);
        drone_positions_y.read(drone0_y,0);
        drone_positions_x.read(drone1_x,1);
        drone_positions_y.read(drone1_y,1);
        drone_positions_x.read(drone2_x,2);
        drone_positions_y.read(drone2_y,2);
        
        
        bit<32> temp_mask;
        
        if (hdr.drone.drone_id == 0){
            //read from its inbox which drones has sent broadcast
            temp_mask = value0 & drone_1;
            if (temp_mask != 0){
                hdr.drone.drone1_broadcastx = drone1_x;
                hdr.drone.drone1_broadcasty = drone1_y;
            }
            temp_mask = value0 & drone_2;
            if (temp_mask != 0){
                hdr.drone.drone2_broadcastx = drone2_x;
                hdr.drone.drone2_broadcasty = drone2_y;
            }
            //empty the drone's own inbox after reading
            value0 = 0;
        }
        
        if (hdr.drone.drone_id == 1){
            temp_mask = value1 & drone_0;
            if (temp_mask != 0){
                hdr.drone.drone0_broadcastx = drone0_x;
                hdr.drone.drone0_broadcasty = drone0_y;
            }
            temp_mask = value1 & drone_2;
            if (temp_mask != 0){
                hdr.drone.drone2_broadcastx = drone2_x;
                hdr.drone.drone2_broadcasty = drone2_y;
            }
            value1 = 0;
        }
        
        
        if (hdr.drone.drone_id == 2){
            temp_mask = value2 & drone_0;
            if (temp_mask != 0){
                hdr.drone.drone0_broadcastx = drone0_x;
                hdr.drone.drone0_broadcasty = drone0_y;
            }
            temp_mask = value2 & drone_1;
            if (temp_mask != 0){
                hdr.drone.drone1_broadcastx = drone1_x;
                hdr.drone.drone1_broadcasty = drone1_y;
            }
            value2 = 0;
        }
    
    	inbox.write(0,value0);
        inbox.write(1,value1);
        inbox.write(2,value2);
    
    }
    
    
    
    action operation_broadcast(){
    
        received_broadcast(); 
    
        bit<32> value0;
        bit<32> value1;
        bit<32> value2;
        
        inbox.read(value0,0);
        inbox.read(value1,1);
        inbox.read(value2,2);
        
        if (hdr.drone.drone_id == 0){
            value1 = value1 | drone_0;
            value2 = value2 | drone_0;
        }
        
        if (hdr.drone.drone_id == 1){
            value0 = value0 | drone_1;
            value2 = value2 | drone_1;
        }
        if (hdr.drone.drone_id == 2){
            value0 = value0 | drone_2;
            value1 = value1 | drone_2;
        }
        
        inbox.write(0,value0);
        inbox.write(1,value1);
        inbox.write(2,value2);
        
    
        
    }
    
    
    action operation_forward() {
        received_broadcast();
        bit<32> new_posy = hdr.drone.positiony + 1;
        check_collision(hdr.drone.positionx, new_posy);
        if (hdr.drone.res == Drone_y){
            send_back(Drone_y);
            }
        else{  
            send_back(Drone_n);
            new_posy = new_posy -1;
            }
        update_position(hdr.drone.drone_id, hdr.drone.positionx, new_posy);
    }

    action operation_backward() {
        received_broadcast();
        bit<32> new_posy = hdr.drone.positiony - 1;
        check_collision(hdr.drone.positionx, new_posy);
        if (hdr.drone.res == Drone_y){
            send_back(Drone_y);
            }
        else{
           
            send_back(Drone_n);
            new_posy = new_posy +1;
            }
         update_position(hdr.drone.drone_id, hdr.drone.positionx, new_posy);
    }

    action operation_right() {
        received_broadcast();
        bit<32> new_posx = hdr.drone.positionx + 1;
        check_collision(new_posx, hdr.drone.positiony);
        if (hdr.drone.res == Drone_y){
            send_back(Drone_y);
            }
        else{
            send_back(Drone_n);
            new_posx = new_posx-1;
            }
        update_position(hdr.drone.drone_id, new_posx, hdr.drone.positiony);
    }

    action operation_left() {
       received_broadcast();
       bit<32> new_posx = hdr.drone.positionx - 1;
        check_collision(new_posx, hdr.drone.positiony);
        if (hdr.drone.res == Drone_y){
            send_back(Drone_y);
            }
        else{
            send_back(Drone_n);
            new_posx = new_posx+1;
            }
        update_position(hdr.drone.drone_id, new_posx, hdr.drone.positiony);
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
            operation_broadcast;
            operation_drop;
        }
        const default_action = operation_drop();
        const entries = {
            Drone_F : operation_forward();
            Drone_B : operation_backward();
            Drone_L : operation_left();
            Drone_R : operation_right();
            Drone_Q : operation_broadcast();
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

