#ifndef OA_RESTARTABLE_FIXTURE_H
#define OA_RESTARTABLE_FIXTURE_H

#include "../../phase6/kernel_abi.h"
#include "model.h"

#include <locale.h>
#include <stdint.h>
#include <wchar.h>

_Static_assert(sizeof(wchar_t)==4 && sizeof(size_t)==8 && WCHAR_MIN==INT32_MIN,
               "Linux LP64 conversion value widths");

enum operation { LENGTH,DECODE,ENCODE,INITIAL,OPERATIONS };
enum { SCALAR_MARK=0x31415926, BYTE_MARK=0x5a };

static inline enum operation operation_from(const char *name)
{
    if (same_text(name,"mbrlen")) return LENGTH;
    if (same_text(name,"mbrtowc")) return DECODE;
    if (same_text(name,"wcrtomb")) return ENCODE;
    if (same_text(name,"mbsinit")) return INITIAL;
    return OPERATIONS;
}

static inline size_t public_length(const char *bytes,size_t count,mbstate_t *state)
{
    size_t (*volatile entry)(const char *,size_t,mbstate_t *)=mbrlen;
    return entry(bytes,count,state);
}

struct state_box { uint64_t before; mbstate_t state; uint64_t after; };
struct wide_box { uint64_t before; wchar_t value; uint64_t after; };

static inline struct state_box fresh_state(void)
{
    mbstate_t initial={0};
    return (struct state_box){UINT64_C(0x84b3f27861d591c4),initial,UINT64_C(0xe1f8d75a239874bc)};
}

static inline int state_guards(const struct state_box *box)
{
    return box->before==UINT64_C(0x84b3f27861d591c4) && box->after==UINT64_C(0xe1f8d75a239874bc);
}

static inline int same_bytes(const unsigned char *a,const unsigned char *b,size_t count)
{
    for (size_t i=0;i<count;++i)
        if (a[i]!=b[i])
            return 0;
    return 1;
}
#endif
