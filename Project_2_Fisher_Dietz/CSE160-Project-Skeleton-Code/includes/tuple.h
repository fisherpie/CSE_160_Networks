#ifndef TUPLE_H
#define TUPLE_H


typedef struct tuple {
	uint16_t src;
  uint16_t seq;
} tuple;

void logTuple(tuple *input){
	dbg(GENERAL_CHANNEL, "Seq: %i Src: %i\n", input->src, input->seq);
}

#endif
