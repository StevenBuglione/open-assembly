#include "packets.h"

static void observe(const struct request *input, struct response *answer)
{
    unsigned mode = (unsigned)(input->shape % 16);
    size_t extent, result = (size_t)UINT64_C(0x92dc6716af);
    const unsigned char *bytes = shape(input, mode, &extent);
    unsigned needle = (unsigned)(input->request & 255);
    if (mode == 7)
        needle = (unsigned)(input->request & UINT32_MAX) | 256;
    else if (mode >= 8 && (mode & 1))
        needle = (unsigned)(input->content >> ((input->request % 8) * 8)) & 255;
    answer->status = slice_find_byte(bytes, extent, needle, mode == NO_OUTPUT ? NULL : &result);
    answer->output = result;
}
