#ifndef AL_PHASE3_CHECK_H
#define AL_PHASE3_CHECK_H

#include <stddef.h>
#include <stdint.h>

#define REQUIRE(condition, status) do { if (!(condition)) return (status); } while (0)
enum { ERROR_SENTINEL = 819, LARGE_REQUEST = 131073 };

static inline int same(const char *left, const char *right)
{
    if (!left || !right)
        return left == right;
    while (*left && *left == *right) {
        ++left;
        ++right;
    }
    return *left == *right;
}

static inline int aligned(const void *pointer, size_t alignment)
{
    return pointer && ((uintptr_t)pointer & (alignment - 1)) == 0;
}

static inline uint32_t next(uint32_t *state)
{
    uint32_t value = *state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    return *state = value;
}

#endif
