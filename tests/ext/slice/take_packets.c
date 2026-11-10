#include "packets.h"

static void observe(const struct request *input, struct response *answer)
{
    unsigned mode = (unsigned)(input->shape % 16);
    size_t available;
    uintptr_t base = (uintptr_t)shape(input, mode, &available);
    if (mode != EMPTY && mode != BAD_BASE && mode != WRAP)
        base = (uintptr_t)(input->content & UINT64_C(0xfffffff)) + 1;
    const unsigned char *cursor = (const unsigned char *)base;
    const unsigned char *result = (const unsigned char *)(uintptr_t)0x6f31;
    size_t requested = input->request % 12;
    answer->status = slice_take(mode == NO_CURSOR ? NULL : &cursor,
                                mode == NO_LENGTH ? NULL : &available, requested,
                                mode == NO_OUTPUT ? NULL : &result);
    answer->first = (uintptr_t)cursor;
    answer->second = available;
    answer->output = (uintptr_t)result;
}
