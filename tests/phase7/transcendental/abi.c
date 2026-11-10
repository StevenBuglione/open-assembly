#include <math.h>
#include <stdint.h>

extern unsigned phase7_scalar_abi_probe(uintptr_t function, uint64_t first, uint64_t second);

int main(void)
{
#if TEST_FORMAT == 32
    /* XMM low words are positive, normal binary32. High words are unspecified. */
    const uint64_t arguments[][2] = {
        {UINT64_C(0xc14570883f000000), UINT64_C(0x7170555540000000)},
        {UINT64_C(0xff7fffff3f800000), UINT64_C(0x807254ab3f000000)},
        {UINT64_C(0x125624ef40000000), UINT64_C(0x917861003f800000)}
    };
#elif TEST_FORMAT == 64
    const uint64_t arguments[][2] = {
        {UINT64_C(0x3fe0000000000000), UINT64_C(0x4000000000000000)},
        {UINT64_C(0x3ff0000000000000), UINT64_C(0x3fe0000000000000)},
        {UINT64_C(0x4000000000000000), UINT64_C(0x3ff0000000000000)}
    };
#else
#error expected TEST_FORMAT=32 or TEST_FORMAT=64
#endif
    for (unsigned i = 0; i < sizeof arguments / sizeof *arguments; ++i)
        if (phase7_scalar_abi_probe((uintptr_t)TEST_FUNCTION, arguments[i][0], arguments[i][1]))
            return 11;
    return 0;
}
