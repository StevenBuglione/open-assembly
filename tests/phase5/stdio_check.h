#ifndef AL_PHASE5_STDIO_CHECK_H
#define AL_PHASE5_STDIO_CHECK_H

#include <stddef.h>
#include <stdint.h>

#include "fp_machine.h"

#define REQUIRE(condition, status) do { if (!(condition)) return (status); } while (0)

static inline int equal(const char *a, const char *b)
{
    while (*a && *a == *b) {
        ++a;
        ++b;
    }
    return *a == *b;
}

static inline size_t length(const char *text)
{
    size_t size = 0;
    while (text[size])
        ++size;
    return size;
}

static inline uint32_t float_bits(float value)
{
    union { float value; uint32_t bits; } data = {.value = value};
    return data.bits;
}

static inline uint64_t double_bits(double value)
{
    union { double value; uint64_t bits; } data = {.value = value};
    return data.bits;
}

static inline int extended_next(long double value)
{
    union { long double value; unsigned char bytes[16]; } data = {.value = value};
    static const unsigned char next[] = {1, 0, 0, 0, 0, 0, 0, 128, 255, 63};
    for (size_t i = 0; i < sizeof next; ++i)
        if (data.bytes[i] != next[i])
            return 0;
    return 1;
}

static inline void rounding(unsigned mode)
{
    struct machine_fenv state = observe();
    unsigned short control = (unsigned short)((state.control & ~0x0c00u) | mode);
    unsigned mxcsr = (state.mxcsr & ~0x6000u) | (mode << 3);
    install(control, mxcsr);
}

#endif
