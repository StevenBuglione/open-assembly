#include "packets.h"

static void observe(struct request *input, struct response *result)
{
    result->status = arena_reset((input->flags & 15) == 0 ? NULL : result->state);
}
