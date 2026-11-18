#ifndef OA_RESTARTABLE_MODEL_H
#define OA_RESTARTABLE_MODEL_H
#include <stddef.h>
#include <stdint.h>

struct logical_state { uint32_t value; unsigned remaining,total,lead; };
struct decoded { size_t result; uint32_t scalar; int wrote,error,initial; };

size_t scalar_bytes(uint32_t scalar,int utf8,unsigned char output[4]);
struct decoded decode_bytes(struct logical_state *state,const unsigned char *bytes,size_t count,int utf8);
#endif
