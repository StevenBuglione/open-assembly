#ifndef OA_WIDE_SEARCH_COPY_FIXTURE_H
#define OA_WIDE_SEARCH_COPY_FIXTURE_H

#include "../../phase6/kernel_abi.h"

#include <stdint.h>
#include <wchar.h>

_Static_assert(sizeof(wchar_t) == 4 && WCHAR_MIN == INT32_MIN && WCHAR_MAX == INT32_MAX,
               "Linux LP64 signed wchar_t");

enum operation { FIRST, LAST, COPY, NCOPY, OPERATIONS };

static inline enum operation operation_from(const char *name)
{
    if (same_text(name, "wcschr"))
        return FIRST;
    if (same_text(name, "wcsrchr"))
        return LAST;
    if (same_text(name, "wcscpy"))
        return COPY;
    if (same_text(name, "wcsncpy"))
        return NCOPY;
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
