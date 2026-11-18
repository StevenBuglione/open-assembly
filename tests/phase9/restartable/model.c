#include "model.h"

size_t scalar_bytes(uint32_t scalar,int utf8,unsigned char output[4])
{
    volatile unsigned char *bytes=output;
    if (!utf8 && scalar>127)
        return (size_t)-1;
    if (scalar>0x10ffff || (scalar>=0xd800 && scalar<=0xdfff))
        return (size_t)-1;
    if (scalar<0x80) {
        bytes[0]=(unsigned char)scalar;
        return 1;
    }
    if (scalar<0x800) {
        bytes[0]=(unsigned char)(0xc0|(scalar>>6));
        bytes[1]=(unsigned char)(0x80|(scalar&63));
        return 2;
    }
    if (scalar<0x10000) {
        bytes[0]=(unsigned char)(0xe0|(scalar>>12));
        bytes[1]=(unsigned char)(0x80|((scalar>>6)&63));
        bytes[2]=(unsigned char)(0x80|(scalar&63));
        return 3;
    }
    bytes[0]=(unsigned char)(0xf0|(scalar>>18));
    bytes[1]=(unsigned char)(0x80|((scalar>>12)&63));
    bytes[2]=(unsigned char)(0x80|((scalar>>6)&63));
    bytes[3]=(unsigned char)(0x80|(scalar&63));
    return 4;
}

struct decoded decode_bytes(struct logical_state *state,const unsigned char *input,size_t count,int utf8)
{
    const volatile unsigned char *bytes=input;
    for (size_t i=0;i<count;++i) {
        unsigned byte=bytes[i];
        if (!state->remaining) {
            if (byte<128)
                return (struct decoded){byte ? i+1 : 0,byte,1,0,1};
            if (!utf8 || byte<0xc2 || byte>0xf4)
                goto invalid;
            state->lead=byte;
            state->total=byte<0xe0 ? 2 : byte<0xf0 ? 3 : 4;
            state->remaining=state->total-1;
            state->value=byte&(state->total==2 ? 31U : state->total==3 ? 15U : 7U);
        } else {
            if (byte<0x80 || byte>0xbf)
                goto invalid;
            if (state->remaining==state->total-1 &&
                ((state->lead==0xe0 && byte<0xa0) || (state->lead==0xed && byte>0x9f) ||
                 (state->lead==0xf0 && byte<0x90) || (state->lead==0xf4 && byte>0x8f)))
                goto invalid;
            state->value=(state->value<<6)|(byte&63);
            --state->remaining;
            if (!state->remaining) {
                uint32_t scalar=state->value;
                state->value=state->total=state->lead=0;
                return (struct decoded){i+1,scalar,1,0,1};
            }
        }
    }
    return (struct decoded){(size_t)-2,0,0,0,state->remaining==0};
invalid:
    state->value=state->remaining=state->total=state->lead=0;
    return (struct decoded){(size_t)-1,0,0,1,1};
}
