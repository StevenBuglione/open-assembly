#ifndef AL_PHASE4_CHECK_H
#define AL_PHASE4_CHECK_H

#include <stddef.h>
#include <stdint.h>

#define REQUIRE(condition, status) do { if (!(condition)) return (status); } while (0)

static inline int same(const char *a, const char *b)
{
    while (*a && *a == *b) {
        ++a;
        ++b;
    }
    return *a == *b;
}

static inline int bytes_equal(const void *left, const void *right, size_t size)
{
    const unsigned char *a = left, *b = right;
    for (size_t i = 0; i < size; ++i)
        if (a[i] != b[i])
            return 0;
    return 1;
}

#endif
