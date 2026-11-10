#include "packets.h"

static void observe(struct request *input, struct response *result)
{
    size_t size = input->a, alignment = input->b;
    size_t *state = result->state;
    switch (input->flags >> 4 & 3) {
    case 0:
        state[0] &= 65535;
        state[1] &= 4095;
        state[2] %= state[1] + 1;
        size &= 4095;
        alignment = (size_t)1 << (alignment & 7);
        break;
    case 1:
        state[0] = SIZE_MAX - (state[0] & 63);
        state[1] &= 127;
        state[2] %= state[1] + 1;
        size &= 15;
        alignment = (size_t)1 << (alignment & 63);
        break;
    case 2:
        state[0] &= 4095;
        state[1] &= 4095;
        state[2] &= 4095;
        size = input->flags & 64 ? 0 : SIZE_MAX - (size & 63);
        alignment = (size_t)1 << (alignment & 7);
        break;
    }
    void *output = (void *)(uintptr_t)result->output;
    result->status = arena_alloc((input->flags & 15) == 0 ? NULL : state, size, alignment,
                                 (input->flags & 15) == 1 ? NULL : &output);
    result->output = (uintptr_t)output;
}
