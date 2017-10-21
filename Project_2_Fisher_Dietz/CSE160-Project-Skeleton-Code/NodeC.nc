/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {
    //component signatures contain 0 or more interfaces
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    components new TimerMilliC() as myTimerC; // create a new timer with alias "myTimerC"


    Node.periodicTimer -> myTimerC; // wire the interface to the component

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    components new HashmapC(uint16_t, 25) as myHashmap;
    Node.neighborMap -> myHashmap;

    components new ListC(uint16_t, 30) as myNeighbors;
    Node.neighborList -> myNeighbors;


    components new ListC(tuple, 30) as myTuple;
    Node.tupleList -> myTuple;

    components RandomC as Random;
    Node.Random -> Random;





}
