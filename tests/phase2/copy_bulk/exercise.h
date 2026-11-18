#ifndef COPY_BULK_EXERCISE_H
#define COPY_BULK_EXERCISE_H
#include "fixture.h"
/* All arrays are declared wchar_t objects; byte accesses inspect their legal
 * object representations. All pointer arithmetic stays inside owned objects. */
enum { MAX_WORDS = 65536, LENGTHS = 35 };
static wchar_t storage_a[MAX_WORDS], storage_b[MAX_WORDS];
static wchar_t original_a[MAX_WORDS], original_b[MAX_WORDS], expected_b[MAX_WORDS];
struct observed { uint64_t result, bytes, units, from, to, kind, source, destination; };
_Static_assert(sizeof(struct observed) == 64, "fixed output width");
struct arena { unsigned char *mapping, *body; size_t length, page; };

static inline int arena_open(struct arena *a, size_t page)
{
    size_t length = 14 * page;
    long p = kernel_call(__NR_mmap, 0, (long)length, PROT_NONE,
                        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (p < 0) return 91;
    a->mapping = (unsigned char *)p;
    a->body = a->mapping + page;
    a->length = length;
    a->page = page;
    if (kernel_call(__NR_mprotect, (long)a->body, (long)(12 * page),
                    PROT_READ | PROT_WRITE, 0, 0, 0)) return 91;
    return 0;
}
static inline int arena_close(const struct arena *a)
{
    return kernel_call(__NR_munmap, (long)a->mapping, (long)a->length, 0, 0, 0, 0) ? 92 : 0;
}
static inline size_t selected_length(unsigned index, size_t page, enum operation op)
{
    size_t p = op == WORD_COPY ? page / 4 : page;
    const size_t n[LENGTHS] = {op == WORD_COPY ? 257 : 1025,
        0, 1, 3, 7, 15, 16, 17, 31, 32, 33, 63, 64, 65,
        op == WORD_COPY ? 127 : 255, op == WORD_COPY ? 128 : 256,
        op == WORD_COPY ? 129 : 257, op == WORD_COPY ? 255 : 511,
        op == WORD_COPY ? 256 : 512, op == WORD_COPY ? 257 : 513,
        1023, 1024, 1025, 2047, 2048, 2049,
        p - 1, p, p + 1, 2*p - 1, 2*p, 2*p + 1, 4*p - 1, 4*p, 4*p + 1};
    return n[index % LENGTHS];
}

#ifdef OA_COPY_ABI
extern unsigned phase2_abi_probe_result(uintptr_t, const uint64_t[6], uint64_t[2]);
#endif
static int invoke(enum operation op, void *dst, const void *src, size_t units)
{
    void *returned;
    errno = TEST_ERRNO;
#ifdef OA_COPY_ABI
    uintptr_t fn = op == BYTE_COPY ? (uintptr_t)memcpy :
                   op == WORD_COPY ? (uintptr_t)wmemcpy : (uintptr_t)memmove;
    uint64_t arguments[6] = {(uintptr_t)dst, (uintptr_t)src, units,
        UINT64_C(0x9147aac62ef309a5), UINT64_C(0xff14e7a9b85436c2), UINT64_C(0x736aba3dc9127745)};
    uint64_t result[2] = {UINT64_MAX, UINT64_MAX};
    if (phase2_abi_probe_result(fn, arguments, result)) return 11;
    returned = (void *)(uintptr_t)result[0];
    if (returned != dst) return 12;
#else
    returned = op == BYTE_COPY ? memcpy(dst, src, units) :
               op == WORD_COPY ? (void *)wmemcpy(dst, src, units) : memmove(dst, src, units);
    if (returned != dst) return 21;
#endif
    if (op == WORD_COPY && errno != TEST_ERRNO) return 24;
    return 0;
}

static int exercise(enum operation op, uint64_t selector, uint64_t seed,
                    size_t page, struct arena *ga, struct arena *gb, struct observed *out)
{
    size_t units = selected_length((unsigned)((selector & 255) % LENGTHS), page, op);
    size_t bytes = units * (op == WORD_COPY ? 4 : 1);
    unsigned kind = op == BYTE_MOVE ? (unsigned)(((selector >> 8) & 7) % 7) : 0;
    size_t body = 12 * page;
    if (body > sizeof storage_a || page < 1024 || page % 4) return 93;
    unsigned char *a = ga ? ga->body : (unsigned char *)storage_a;
    unsigned char *b = gb ? gb->body : (unsigned char *)storage_b;
    unsigned char *oa = (unsigned char *)original_a, *ob = (unsigned char *)original_b;
    unsigned char *expected = (unsigned char *)expected_b;
    model_fill((wchar_t *)a, body / 4, seed, 0);
    model_fill((wchar_t *)b, body / 4, seed, 1);
    model_copy(oa, a, body);
    model_copy(ob, b, body);
    size_t from = 64 + (size_t)(seed & 31), to = 64 + (size_t)((seed >> 5) & 31);
    if (op == WORD_COPY) { from &= ~(size_t)3; to &= ~(size_t)3; }
    size_t shift = kind == 3 || kind == 4 ? 17 : kind == 6 ? bytes + 64 : 1;
    if (kind) {
        b = a;
        from = 64;
        to = kind == 5 ? from : from + shift;
        if (kind == 2 || kind == 4) { to = 64; from = to + shift; }
    }
    if (ga) {
        if (!kind) {
            from = (selector >> 62) & 1 ? body - bytes : 0;
            to = (selector >> 63) & 1 ? body - bytes : 0;
        } else {
            size_t span = bytes + (kind == 5 ? 0 : shift);
            size_t start = selector >> 63 ? body - span : 0;
            from = start;
            to = start + (kind == 5 ? 0 : shift);
            if (kind == 2 || kind == 4) { to = start; from = start + shift; }
        }
    }
    model_copy(expected, kind ? oa : ob, body);
    model_copy(expected + to, oa + from, bytes);
    int status = invoke(op, b + to, a + from, units);
    if (status) return status;
    if (!model_equal(b + to, expected + to, bytes)) return 22;
    for (size_t i = 0; i < body; ++i)
        if ((i < to || i >= to + bytes) && b[i] != expected[i]) return 23;
    if (!kind && !model_equal(a, oa, body)) return 23;
    if (out) *out = (struct observed){0, bytes, units, from, to, kind,
        model_digest(a, body), model_digest(b, body)};
    return 0;
}
#endif
