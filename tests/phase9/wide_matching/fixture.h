#ifndef OA_WIDE_MATCHING_FIXTURE_H
#define OA_WIDE_MATCHING_FIXTURE_H

#include "../../phase6/kernel_abi.h"

#include <stdint.h>
#include <wchar.h>

_Static_assert(sizeof(wchar_t) == 4 && WCHAR_MIN == INT32_MIN && WCHAR_MAX == INT32_MAX,
               "Linux LP64 signed wchar_t");

enum operation { SPAN, CSPAN, BREAK, FIND, OPERATIONS };

static inline enum operation operation_from(const char *name)
{
    if (same_text(name, "wcsspn"))
        return SPAN;
    if (same_text(name, "wcscspn"))
        return CSPAN;
    if (same_text(name, "wcspbrk"))
        return BREAK;
    if (same_text(name, "wcsstr"))
        return FIND;
    return OPERATIONS;
}

static inline int same_wide(const wchar_t *left, const wchar_t *right, size_t units)
{
    for (size_t i = 0; i < units; ++i)
        if (left[i] != right[i])
            return 0;
    return 1;
}

static inline wchar_t element(uint32_t bits)
{
    return (wchar_t)(bits <= INT32_MAX ? (int64_t)bits : (int64_t)bits - (INT64_C(1) << 32));
}

#endif
