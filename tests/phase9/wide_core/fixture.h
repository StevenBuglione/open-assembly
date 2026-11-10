#ifndef OA_WIDE_CORE_FIXTURE_H
#define OA_WIDE_CORE_FIXTURE_H

#include "../../phase6/kernel_abi.h"

#include <stdint.h>
#include <wchar.h>

_Static_assert(sizeof(wchar_t) == 4 && WCHAR_MIN == INT32_MIN && WCHAR_MAX == INT32_MAX,
               "Linux LP64 signed wchar_t");

enum operation { LEN, CMP, NCMP, CHR, OPERATIONS };

static inline enum operation operation_from(const char *name)
{
    if (same_text(name, "wcslen"))
        return LEN;
    if (same_text(name, "wcscmp"))
        return CMP;
    if (same_text(name, "wcsncmp"))
        return NCMP;
    if (same_text(name, "wmemchr"))
        return CHR;
    return OPERATIONS;
}

static inline int sign_of(int value)
{
    return (value > 0) - (value < 0);
}

static inline int same_wide(const wchar_t *a, const wchar_t *b, size_t length)
{
    for (size_t i = 0; i < length; ++i)
        if (a[i] != b[i])
            return 0;
    return 1;
}

static inline wchar_t element(uint32_t bits)
{
    return (wchar_t)(bits <= INT32_MAX ? (int64_t)bits : (int64_t)bits - (INT64_C(1) << 32));
}

#endif
