/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   Apr 28 2012
 * 
 */ 

#include <Timer.h>
#include "packet.h"

configuration NodeC{
}
implementation {
	components MainC;
	components Node;
	components RandomC as Random;
	
	components new TimerMilliC() as pingTimeoutTimer;
	components new TimerMilliC() as neighborDiscoveryTimer;
	components new TimerMilliC() as neighborUpdateTimer;
	components new TimerMilliC() as lspTimer;
	
	components ActiveMessageC;
	components new AMSenderC(6);
	components new AMReceiverC(6);

	Node -> MainC.Boot;
	
	//Timers
	Node.pingTimeoutTimer->pingTimeoutTimer;
	
	Node.Random -> Random;
	
	Node.Packet -> AMSenderC;
	Node.AMPacket -> AMSenderC;
	Node.AMSend -> AMSenderC;
	Node.AMControl -> ActiveMessageC;
	Node.neighborDiscoveryTimer-> neighborDiscoveryTimer; // Add this line here.
	Node.neighborUpdateTimer-> neighborUpdateTimer;
	Node.lspTimer->lspTimer;
	Node.Receive -> AMReceiverC;

}
