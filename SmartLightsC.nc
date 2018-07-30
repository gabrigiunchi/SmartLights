#include "Timer.h"
#include "RadioMSG.h"
#include "printf.h"
#include "Pattern.h"
#include "Queue.h"

#define READY_STATE 0
#define PATTERN_STATE 1
#define WAITING_STATE 2

#define CONTROLLER 1
#define N_LIGHTS 10
#define WAITING_TIME 10000
#define START_DELAY 10000
#define SEND_FREQUENCY 50
#define MAX_TRANSMISSION_COUNT 2

#define ACK 2
#define ON_COMMAND 1
#define OFF_COMMAND 0

module SmartLightsC @safe() {
  uses {
    interface Leds;
    interface Boot;
    interface Receive;
    interface AMSend;
    interface Timer<TMilli> as Timer0;
    interface Timer<TMilli> as Timer1;
    interface SplitControl as AMControl;
    interface Packet;
  }
}

implementation {

  /**************** FUNCTIONS  AND VARIABLES DECLARATION ************************************/
  void sendPacket(uint16_t cmd, uint16_t dest, uint16_t address);
  void sendNext();
  void startSend();
  void startController();
  void initRoutingTable();
  void readyState();
  void patternState();
  void waitingState();
  void turnOffAllLights();
  void forwardPacket(uint16_t cmd, uint16_t dest);
  void handleCommand(uint16_t cmd);

  uint16_t routingTable[11];
  message_t packet;
  uint16_t state = READY_STATE;
  uint16_t nextPattern = 0;
  pattern p;
  bool locked = FALSE;
  uint16_t transmissionCount = 0;

  /*************************** GENERAL *****************************************/

  event void Boot.booted() {
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      printf("[%u]: Start mote\n", TOS_NODE_ID);

	initRoutingTable();
      if(TOS_NODE_ID == CONTROLLER) {
		    startController();
      }
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) { }

  event void AMSend.sendDone(message_t* msg, error_t error) { 
    if(&packet == msg) {
      locked = FALSE;
    }
  }

  // Send a packet with parameters [cmd, dest] to the mote with the given address
  void sendPacket(uint16_t cmd, uint16_t dest, uint16_t address) {
  	msg_t* m = (msg_t*)call Packet.getPayload(&packet, sizeof(msg_t));

    printf("[%u]: Send packet {command:%u, destination:%u} to %u\n", TOS_NODE_ID, cmd, dest, address);

    m->commandCode = cmd;
	  m->destination = dest;
    
    if(call AMSend.send(address, &packet, sizeof(msg_t)) == SUCCESS) {
	locked = TRUE;
    }
  }

  // Send the next message waiting in the queue
  void sendNext() {
    msg_t m;

    call Timer1.stop();

    if(locked) return;

    if(transmissionCount == MAX_TRANSMISSION_COUNT && !queueEmpty()) {
	printf("Controller: message has been transmitted too many times, it will be discarded\n");
	transmissionCount = 0;
	dequeue();
    }

    if(!queueEmpty()) {
      m = peek();
     
      switch(m.commandCode) {
        case ON_COMMAND: printf("Controller: Turn on light %u\n", m.destination); break;
        case OFF_COMMAND: printf("Controller: Turn off light %u\n", m.destination); break;
        default: break;
      }

      sendPacket(m.commandCode, m.destination, routingTable[m.destination]);
	transmissionCount++;
	call Timer1.startOneShot(500);
    } else {
      if(state == WAITING_STATE) readyState();
      else if(state == PATTERN_STATE) waitingState();
    }
  }

  // Start sending the messages stored in the queue
  void startSend() {
    sendNext();
  }

  event void Timer1.fired() {
    printf("Controller: Timer expired, retransmit message\n");
    sendNext();
  }

  /********************* CONTROLLER *****************************************/

  // Initialize the routing table and the patterns used by the controller
  void startController() {
    //initRoutingTable();
    initPatterns();
    readyState();
  }

  void initRoutingTable() {
    routingTable[0] = AM_BROADCAST_ADDR;
    routingTable[1] = 1;
    routingTable[2] = 2;
    routingTable[3] = 2;
    routingTable[4] = 2;
    routingTable[5] = 5;
    routingTable[6] = 5;
    routingTable[7] = 5;
    routingTable[8] = 8;
    routingTable[9] = 8;
    routingTable[10] = 8;
  }

  void readyState() {
    state = READY_STATE;
    call Leds.led0On();
    call Leds.led1Off();
    call Leds.led2Off();
    printf("Controller: Ready state\n");
    call Timer0.startOneShot(START_DELAY); // Transition to the pattern state
  }

  void patternState() {
    uint16_t i;
    msg_t m;

    p = patterns[nextPattern];
    state = PATTERN_STATE;
    call Leds.led0Off();
    call Leds.led1On();
    call Leds.led2Off();

    printf("Controller: Start pattern %s\n", p.name);

    // Turn on all the lights in the pattern
    for(i = 0; i < p.size; i++) { 
      m.commandCode = ON_COMMAND;
      m.destination = p.lights[i];
      enqueue(m);
    }

    nextPattern = (nextPattern + 1) % N_PATTERNS;
    startSend();
  }

  void waitingState() {
    state = WAITING_STATE;
    call Leds.led0Off();
    call Leds.led1Off();
    call Leds.led2On();
    printf("Controller: Waiting state\n");
    call Timer0.startOneShot(WAITING_TIME); // Transition to the ready state
  }

  event void Timer0.fired() {
    switch(state) {
      case READY_STATE: patternState(); break;
      case PATTERN_STATE: break;
      case WAITING_STATE: turnOffAllLights(); break;
      default: break;
    }
  }

  void turnOffAllLights() {
    uint16_t i;
    msg_t m;
    
    printf("Controller: Turn off all the lights\n");
    for(i = 0; i < p.size; i++) {
      m.commandCode = OFF_COMMAND;
      m.destination = p.lights[i];
      enqueue(m);
    }
    startSend();
  }

  /***************************** LIGHT *********************************************************/

  // Send the packet to the next mote
  void forwardPacket(uint16_t cmd, uint16_t dest) {
    uint16_t next = TOS_NODE_ID < dest? TOS_NODE_ID + 1 : TOS_NODE_ID - 1;
    if(dest == CONTROLLER && routingTable[TOS_NODE_ID] == TOS_NODE_ID) {
	next = CONTROLLER;
    }
	  printf("[%u]: Forward packet to %u\n", TOS_NODE_ID, next);
	  sendPacket(cmd, dest, next);
  }

  void sendAck() {
        uint16_t next = TOS_NODE_ID -1;
        if(TOS_NODE_ID == 2 || TOS_NODE_ID == 5 || TOS_NODE_ID == 8) {
		next = CONTROLLER;
	}
	printf("[%u]: Send ack to controller \n", TOS_NODE_ID);
	sendPacket(ACK, CONTROLLER, next);
  }

  // Handle the command received
  void handleCommand(uint16_t cmd) {
 	  printf("[%u]: Handle command: %u\n", TOS_NODE_ID, cmd);

    switch(cmd) {
      case OFF_COMMAND: {
            	call Leds.led0Off(); 
		sendAck();
		break;
      }
      case ON_COMMAND: {
		call Leds.led0On(); 
		sendAck();
		break;
      }
      default: break;
    }
  }

  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    if (len != sizeof(msg_t)) {
      return bufPtr;
    }
    
    else {
      msg_t* m = (msg_t*)payload;

      printf("[%u]: Received packet {command:%u, destination:%u}\n", TOS_NODE_ID, m->commandCode, m->destination);

	if(TOS_NODE_ID == CONTROLLER) {
		if(m->commandCode == ACK) {
			dequeue();
			transmissionCount = 0;
			sendNext();
		}
 	}

	else {

	      /*
		Three cases:

		1) the mote is the destination of the message -> handle the message
		2) the message is a broadcast message -> handle it and then forward
		3) otherwise just forward the messsage to the next mote

	      */
	      if(m->destination == TOS_NODE_ID) {
		handleCommand(m->commandCode);
	      }
	      else if(m->destination == AM_BROADCAST_ADDR) {
	      	handleCommand(m->commandCode);
		      forwardPacket(m->commandCode, m->destination);
	      }
	      else {
		forwardPacket(m->commandCode, m->destination);
	      }
	}

      return bufPtr;
    }
  }
}




