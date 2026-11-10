#include "packets.h"

static void observe(struct request *input, struct response *result)
{
    size_t base = input->a, capacity = input->b;
    switch (input->flags >> 4 & 3) {
    case 0:
        base &= 65535;
        capacity &= 65535;
        break;
    case 1:
        base = 0;
        capacity &= 1;
        break;
    case 2:
        base = SIZE_MAX - (base & 63);
        capacity &= 127;
        break;
    }
    result->status = arena_init((input->flags & 15) == 0 ? NULL : result->state,
                                (void *)(uintptr_t)base, capacity);
}
