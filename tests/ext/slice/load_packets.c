#include "packets.h"

static void observe(const struct request *input, struct response *answer)
{
    unsigned mode = (unsigned)(input->shape % 16);
    size_t extent;
    const unsigned char *bytes = shape(input, mode, &extent);
    unsigned result = UINT32_C(0x912abb33);
    answer->status = slice_load_u32be(bytes, extent, mode == NO_OUTPUT ? NULL : &result);
    answer->output = result;
}
