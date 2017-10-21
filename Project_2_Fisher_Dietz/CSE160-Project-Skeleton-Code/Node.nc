#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/tuple.h"
#include "includes/lspTable.h" //NEW
#include "includes/list.h" //NEW
#include "includes/pair.h" //NEW
#include "includes/packBuffer.h" //NEW

module Node {
    uses interface Boot;
    uses interface SplitControl as AMControl;
    uses interface Receive;
    uses interface SimpleSend as Sender;
    uses interface CommandHandler;

    uses interface Timer<TMilli> as periodicTimer;
    uses interface Hashmap<uint16_t> as neighborMap;
    uses interface List<uint16_t> as neighborList;
    uses interface List<tuple> as tupleList;
    uses interface Random;
}

implementation {
    pack sendPackage;
    int sequence = 0;
    tuple Tuple;

    // PROJ 2 ******************************************************************************************
    int totalNodes = 10;
	int discoveryPacket = AM_BROADCAST_ADDR;
    sendBuffer packBuffer;

    uint16_t linkSequenceNum = 0;
    lspTable confirmedList;
	lspTable tentativeList;
	lspMap lspMAP[20];
	arrlist lspTracker;
    arrlist friendList;
	float cost[20];
	int lastSequenceTracker[20] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
	float totalAverageEMA[20] =  {0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215,0.0039215};

	void printlspMap(lspMap *list);
	void lspNeighborDiscoveryPacket();
	void dijkstra();
	int forwardPacketTo(lspTable* list, int dest);
	void printCostList(lspMap *list, uint8_t nodeID);
	float EMA(float prevEMA, float now,float weight);
    // ******************************************************************************************

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    void makeTuple(tuple *tpl, uint16_t src, uint16_t seq);
    void startNeighborDiscovery();
    void handleNeighborDiscovery(message_t* msg, void* payload);

    event void Boot.booted() {
        call AMControl.start();

        dbg(GENERAL_CHANNEL, "Booted\n");

        call periodicTimer.startPeriodic(call Random.rand32() % 2000);    //start timer with random interval
    }

    event void AMControl.startDone(error_t err) {
        if (err == SUCCESS)
            dbg(GENERAL_CHANNEL, "Radio On\n");
        else
            call AMControl.start();    //keeps retrying
    }

    event void AMControl.stopDone(error_t err){}

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {

        dbg(GENERAL_CHANNEL, "Packet Received\n");
        if (len == sizeof(pack)) {
            pack* myMsg = (pack*) payload;
            logPack(myMsg);
            dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);

            switch(myMsg->protocol) {
                case PROTOCOL_NEIGHDMP:
                handleNeighborDiscovery(msg, payload);
                return msg;

                case PROTOCOL_PING:
                dbg(GENERAL_CHANNEL, "Protocol is PING\n");

                if (myMsg->src == TOS_NODE_ID) {    //if receiving node is the source, won't send
                    dbg(GENERAL_CHANNEL, "Receiving is source; won't send.\n");
                    return msg;
                }

                if (myMsg->dest == TOS_NODE_ID) {   //checks the destination
                    dbg(GENERAL_CHANNEL, "Replying to source.\n");
                    dbg(GENERAL_CHANNEL, "Arrived at destination: (%i)\n\n", TOS_NODE_ID);
                    dbg(GENERAL_CHANNEL, "Payload: %s\n", myMsg->payload);
                    sequence++;
                    makePack(&sendPackage, TOS_NODE_ID, myMsg->src, MAX_TTL, PROTOCOL_PINGREPLY, sequence, payload, PACKET_MAX_PAYLOAD_SIZE);
                    call Sender.send(sendPackage, AM_BROADCAST_ADDR);
                    return msg;
                }

                if (myMsg->TTL <= 0) {    //checks the TTL
                    dbg(GENERAL_CHANNEL, "TTL is 0; drop the packet.\n");
                    return msg;
                }

                if (!(call tupleList.isEmpty())) {
                    int i;               
                    for (i = 0; i < call tupleList.size(); i++) {
                        tuple tpl = call tupleList.get(i);
                        if (tpl.src == myMsg->src && tpl.seq == myMsg->seq) {
                            dbg(GENERAL_CHANNEL, "\nPackage seen before; drop the packet.\n\n");
                            return msg;
                        }
                    }
                }

                dbg(GENERAL_CHANNEL, "Package meant for mther ID: (%i)\n", TOS_NODE_ID);   //send packet to neighbots
                myMsg->TTL--;
                makeTuple(&Tuple, myMsg->src, myMsg->seq);
                call tupleList.pushback(Tuple);
                dbg(GENERAL_CHANNEL, "tuple list: \n\n");
                printf("List tuple-> src: %i, seq: %i\n\n", (call tupleList.front()).src, (call tupleList.front()).seq);

                call Sender.send(*myMsg, AM_BROADCAST_ADDR);
                return msg;


                case PROTOCOL_PINGREPLY:
                dbg(GENERAL_CHANNEL, "Protocol is PING_REPLY\n");

                if (myMsg->src == TOS_NODE_ID) {
                    dbg(GENERAL_CHANNEL, "This is source; won't send packet out.\n");
                    return msg;
                }

                /*
                if (myMsg->dest == discoveryPacket) {
                    pair friendListInfo;
                    uint8_t *tempArray;

                    int i, j;
                    int difference;

                    switch(myMsg->protocol) {
                        case PROTOCOL_LINKSTATE:
                            if (!arrlistContains(&lspTracker, myMsg->src, myMsg->seq)) {
                                if (arrListSize)
                            }
                    }
                }
                */

                if (!(call tupleList.isEmpty())) {
                    int i;
                    for (i = 0; i < call tupleList.size(); i++) {
                        tuple tpl = call tupleList.get(i);
                        if (tpl.src == myMsg->src && tpl.seq == myMsg->seq) {
                            dbg(GENERAL_CHANNEL, "\n\nPackage seen before; drop the package.\n\n");
                            return msg;
                        }
                    }
                }

                call Sender.send(*myMsg, AM_BROADCAST_ADDR);
                return msg;
            }
        }
        dbg(GENERAL_CHANNEL, "Packet Type Unknown %d\n", len);
        return msg;
    }

    event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
        dbg(GENERAL_CHANNEL, "PING EVENT \n");
        makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, sequence, payload, PACKET_MAX_PAYLOAD_SIZE);
        sequence++;
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);   //send to neighbors
    }

    event void periodicTimer.fired() {
        dbg(GENERAL_CHANNEL, "Firing timer\n");
        while (!(call neighborList.isEmpty())) {    //checks if the neighbots list is empty
            call neighborList.popfront();
    }
    
    startNeighborDiscovery();
        return;
    }

    event void CommandHandler.printNeighbors() {
        call neighborList.printList();
    }

    event void CommandHandler.printRouteTable() {
    }

    event void CommandHandler.printLinkState() {
    }

    event void CommandHandler.printDistanceVector() {
    }

    event void CommandHandler.setTestServer() {
    }

    event void CommandHandler.setTestClient() {
    }

    event void CommandHandler.setAppServer() {
    }

    event void CommandHandler.setAppClient() {
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length) {
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->protocol = protocol;
        Package->seq = seq;
        memcpy(Package->payload, payload, length);
    }

    void makeTuple(tuple *tpl, uint16_t src, uint16_t seq) {
        tpl->src = src;
        tpl->seq = seq;
    }

    void startNeighborDiscovery() {
        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_NEIGHDMP, sequence, "Hello, World!", PACKET_MAX_PAYLOAD_SIZE);
        sequence++;
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
    }

    void handleNeighborDiscovery(message_t* msg, void* payload) {
        pack* myMsg=(pack*) payload;
        if (myMsg->src == TOS_NODE_ID) {
            call neighborList.pushback(myMsg->dest);
            dbg(NEIGHBOR_CHANNEL, "neighbors: ", TOS_NODE_ID);
            call neighborList.printList();
            return;
        }
        myMsg->dest = TOS_NODE_ID;
        dbg(NEIGHBOR_CHANNEL, "sending to source\n", TOS_NODE_ID, myMsg->src);
        call Sender.send(*myMsg, myMsg->src);
        return;
    }

    // PROJ 2 ******************************************************************************************
	void printlspMap(lspMap *list) {
		int i, j;
		for (i = 0; i < totalNodes; i++) {
			for (j = 0; j < totalNodes; j++) {
				if (list[i].cost[j] != 0 && list[i].cost[j] != -1)
					dbg("Project 2", "src: %d  neighbor: %d cost: %d \n", i, j, list[i].cost[j]);
			}	
		}
		dbg("Project 2", "done\n\n");
	}
	
	void printCostList(lspMap *list, uint8_t nodeID) {
		uint8_t i;
		for (i = 0; i < totalNodes; i++) {
			dbg("genDebug", "costs %d from %d to %d", list[nodeID].cost[i], nodeID, i);
		}
	}

	void lspNeighborDiscoveryPacket() {
		uint16_t dest;
		int i;
		uint8_t lspCostList[20] = {-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};	
		lspMapinitialize(lspMAP,TOS_NODE_ID);
		for (i = 0; i < friendList.numValues; i++) {
			if (1/totalAverageEMA[friendList.values[i].src]*10 < 255) {
				lspCostList[friendList.values[i].src] = 1/totalAverageEMA[friendList.values[i].src]*10;
				dbg("Project 2", "costs %d to %d %f %f\n", lspCostList[friendList.values[i].src], friendList.values[i].src, 1/totalAverageEMA[friendList.values[i].src]*10,totalAverageEMA[friendList.values[i].src]);
				//puts the neighbor into the MAP
				lspMAP[TOS_NODE_ID].cost[friendList.values[i].src] = 1/totalAverageEMA[friendList.values[i].src]*10;
				dbg("Project 2", "neighbors: %d %d\n",friendList.values[i].src, lspCostList[friendList.values[i].src]);
			}
			else
				dbg("Project 2", "%d isn't neighbor\n", friendList.values[i].src);
		}
		memcpy(&dest, "", sizeof(uint8_t));	
		makePack(&sendPackage, TOS_NODE_ID, discoveryPacket, MAX_TTL, PROTOCOL_LINKEDLIST, linkSequenceNum++, (uint8_t *)lspCostList, 20);	
		sendBufferPushBack(*packBuffer, sendPackage, sendPackage.src, discoveryPacket);	
		//post sendBufferTask();
		dbg("Project 2", "sending LSP\n");	
	}	
		
    void dijkstra() {
		int i;	
		lspTuple lspTup, temp;
		lspTableinit(&tentativeList); lspTableinit(&confirmedList);
		dbg("Project 2","starting dijkstra\n");
		lspTablePushBack(&tentativeList, temp = (lspTuple){TOS_NODE_ID,0,TOS_NODE_ID});
		dbg("Project 2","PushBack from tentativeList dest:%d cost:%d nextHop:%d \n", temp.dest, temp.nodeNcost, temp.nextHop);
		while (!lspTableIsEmpty(&tentativeList)) {
			if (!lspTableContains(&confirmedList,lspTup = lspTupleRemoveMinCost(&tentativeList))) //gets the minCost node from the tentative and removes it, then checks if it's in the confirmed list.
				if (lspTablePushBack(&confirmedList,lspTup))
					dbg("Project 2","PushBack from confirmedList dest:%d cost:%d nextHop:%d \n", lspTup.dest,lspTup.nodeNcost, lspTup.nextHop);
			for (i = 1; i < totalNodes; i++) {
				temp = (lspTuple){i,lspMAP[lspTup.dest].cost[i]+lspTup.nodeNcost,(lspTup.nextHop == TOS_NODE_ID)?i:lspTup.nextHop};
				if (!lspTableContainsDest(&confirmedList, i) && lspMAP[lspTup.dest].cost[i] != 255 && lspMAP[i].cost[lspTup.dest] != 255 && lspTupleReplace(&tentativeList,temp,temp.nodeNcost))
						dbg("Project 2","Replace from tentativeList dest:%d cost:%d nextHop:%d\n", temp.dest, temp.nodeNcost, temp.nextHop);
				else if (!lspTableContainsDest(&confirmedList, i) && lspMAP[lspTup.dest].cost[i] != 255 && lspMAP[i].cost[lspTup.dest] != 255 && lspTablePushBack(&tentativeList, temp))
						dbg("Project 2","PushBack from tentativeList dest:%d cost:%d nextHop:%d \n", temp.dest, temp.nodeNcost, temp.nextHop);
			}
		}
		dbg("Project 2", "printing routing table \n");
		for (i = 0; i < confirmedList.numValues; i++)
			dbg("Project 2", "dest:%d cost:%d nextHop:%d \n",confirmedList.lspTuples[i].dest,confirmedList.lspTuples[i].nodeNcost,confirmedList.lspTuples[i].nextHop);
		dbg("Project 2", "finished dijkstra\n");
	}

	int forwardPacketTo(lspTable* list, int dest) {	
		return lspTableLookUp(list,dest);
	}
	
	void costCalculator(int lastSequence, int currentSequence) {
	}

	float EMA(float prevEMA, float now,float weight) {
		float alpha = 0.5*weight;
		float averageEMA = alpha*now + (1-alpha)*prevEMA;
		return averageEMA;
	}
    // ******************************************************************************************

}