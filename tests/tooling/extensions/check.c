#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <word_math.h>

extern unsigned phase2_abi_probe(uintptr_t, const uint64_t[6]);

static unsigned model(unsigned value, unsigned ceiling)
{
    return value > ceiling ? ceiling : value;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    errno = EDOM;
    if (word_math_clamp_u32(37, 19) != 19 || errno != EDOM)
        return 11;
    if (!strcmp(argv[1], "abi")) {
        const uint64_t arguments[6] = {UINT64_C(0xe200000000000021), UINT64_C(0x11000000000000ed)};
        if (phase2_abi_probe((uintptr_t)word_math_clamp_u32, arguments) || errno != EDOM)
            return 12;
        return 0;
    }
    unsigned x = 0x00c0ffeeu;
    const unsigned boundary[] = {0, 1, 0x7fffffffu, 0x80000000u, 0xffffffffu};
    for (size_t i = 0; i < sizeof boundary / sizeof boundary[0]; ++i)
        for (size_t j = 0; j < sizeof boundary / sizeof boundary[0]; ++j)
            if (word_math_clamp_u32(boundary[i], boundary[j]) != model(boundary[i], boundary[j]) || errno != EDOM)
                return 13;
    for (unsigned i = 0; i < 4096; ++i) {
        unsigned value = x = x * 1664525u + 1013904223u;
        unsigned ceiling = x = x * 1664525u + 1013904223u;
        if (word_math_clamp_u32(value, ceiling) != model(value, ceiling) || errno != EDOM)
            return 14;
    }
    return 0;
}
