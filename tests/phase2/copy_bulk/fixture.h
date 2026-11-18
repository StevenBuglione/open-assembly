#ifndef COPY_BULK_FIXTURE_H
#define COPY_BULK_FIXTURE_H
#include "../../phase6/kernel_abi.h"
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <wchar.h>
#include "model.h"
_Static_assert(sizeof(wchar_t) == 4 && WCHAR_MIN == INT32_MIN && WCHAR_MAX == INT32_MAX,
               "signed 32-bit Linux wchar_t");
enum operation { BYTE_COPY, WORD_COPY, BYTE_MOVE, OPERATIONS };
static inline enum operation operation_from(const char *name)
{
    if (same_text(name, "memcpy")) return BYTE_COPY;
    if (same_text(name, "wmemcpy")) return WORD_COPY;
    if (same_text(name, "memmove")) return BYTE_MOVE;
    return OPERATIONS;
}
#ifndef OA_PHASE6_HOST
struct copy_aux { unsigned long type, value; };
extern const struct copy_aux *const __al_auxv;
#endif
static inline size_t page_size(void)
{
#ifdef OA_PHASE6_HOST
    long p = sysconf(_SC_PAGESIZE);
    return p > 0 ? (size_t)p : 0;
#else
    for (const struct copy_aux *a = __al_auxv; a->type; ++a)
        if (a->type == 6) return a->value;
    return 0;
#endif
}
#endif
