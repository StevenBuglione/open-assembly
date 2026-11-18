#include "model.h"

/* Scalar, volatile object accesses prevent compiler memory-helper substitution.
 * Values are constructed independently; no tested copy primitive is imported. */
void model_fill(wchar_t *out, size_t units, uint64_t seed, int blank)
{
    volatile wchar_t *p = out;
    for (size_t i = 0; i < units; ++i) {
        uint32_t bits = UINT32_C(0x5a5a5a5a);
        if (!blank) {
            uint64_t x = seed + (uint64_t)i * UINT64_C(0x9e3779b97f4a7c15);
            x ^= x >> 29;
            x *= UINT64_C(0x94d049bb133111eb);
            bits = (uint32_t)(x ^ (x >> 32));
            switch (i & 31) {
            case 0: bits = 0; break;
            case 1: bits = 1; break;
            case 2: bits = UINT32_MAX; break;
            case 3: bits = UINT32_C(0x80000000); break;
            case 4: bits = UINT32_C(0x7fffffff); break;
            default: break;
            }
            if (bits == UINT32_C(0x5a5a5a5a))
                bits = UINT32_C(0xa7b6c5d4);
        }
        p[i] = (wchar_t)(bits <= INT32_MAX ? (int64_t)bits : (int64_t)bits - (INT64_C(1) << 32));
    }
}

void model_copy(unsigned char *to, const unsigned char *from, size_t bytes)
{
    volatile unsigned char *d = to;
    const volatile unsigned char *s = from;
    for (size_t i = 0; i < bytes; ++i)
        d[i] = s[i];
}

int model_equal(const unsigned char *a, const unsigned char *b, size_t bytes)
{
    const volatile unsigned char *x = a, *y = b;
    for (size_t i = 0; i < bytes; ++i)
        if (x[i] != y[i])
            return 0;
    return 1;
}

uint64_t model_digest(const unsigned char *p, size_t bytes)
{
    const volatile unsigned char *s = p;
    uint64_t value = UINT64_C(0xcbf29ce484222325);
    for (size_t i = 0; i < bytes; ++i)
        value = (value ^ s[i]) * UINT64_C(0x100000001b3);
    return value;
}
