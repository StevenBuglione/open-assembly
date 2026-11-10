#include "../kernel_abi.h"
#include <limits.h>
#include <stdint.h>
#include <time.h>

_Static_assert(sizeof(struct tm) == 56 && _Alignof(struct tm) == 8, "calendar record ABI");
_Static_assert(offsetof(struct tm, tm_year) == 20 && offsetof(struct tm, tm_gmtoff) == 40 &&
               offsetof(struct tm, tm_zone) == 48, "calendar field offsets");

struct civil_case {
    time_t stamp;
    int fields[8];
};

#include "vectors.h"

struct boxed {
    uint64_t before;
    struct tm result;
    uint64_t after;
};

static void fill(void *storage, size_t size)
{
    unsigned char *bytes = storage;
    for (size_t i = 0; i < size; ++i)
        bytes[i] = 0xa5;
}

static int unchanged(const void *storage, size_t size)
{
    const unsigned char *bytes = storage;
    for (size_t i = 0; i < size; ++i) {
        if (bytes[i] != 0xa5)
            return 0;
    }
    return 1;
}

static int civil_matches(const struct tm *got, const int want[8])
{
    const int fields[] = {got->tm_sec, got->tm_min, got->tm_hour, got->tm_mday,
                          got->tm_mon, got->tm_year, got->tm_wday, got->tm_yday};
    for (unsigned i = 0; i < sizeof fields / sizeof fields[0]; ++i) {
        if (fields[i] != want[i])
            return 0;
    }
    if (got->tm_isdst || got->tm_gmtoff || !got->tm_zone)
        return 0;
#ifdef OA_PHASE6_HOST
    if (same_text(got->tm_zone, "GMT"))
        return 1;
#endif
    return same_text(got->tm_zone, "UTC");
}

static int utc_success_errno(void)
{
#if defined(OA_PHASE6_HOST) && defined(__GLIBC__)
    return errno == TEST_ERRNO || errno == ENOENT;
#else
    return errno == TEST_ERRNO;
#endif
}

static int utc_case(void)
{
    errno = TEST_ERRNO;
    struct tm *first = gmtime(&cases[0].stamp);
    if (!first || !utc_success_errno() || !civil_matches(first, cases[0].fields))
        return 11;
    struct tm *second = gmtime(&cases[10].stamp);
    if (first != second || !civil_matches(second, cases[10].fields))
        return 12;
    if (gmtime(&overflow[0]) || errno != EOVERFLOW)
        return 13;
    return 0;
}

static int reentrant_case(void)
{
    for (size_t i = 0; i < sizeof cases / sizeof cases[0]; ++i) {
        struct boxed box;
        fill(&box, sizeof box);
        errno = TEST_ERRNO;
        if (gmtime_r(&cases[i].stamp, &box.result) != &box.result || !utc_success_errno() ||
            !civil_matches(&box.result, cases[i].fields) || !unchanged(&box.before, sizeof box.before) ||
            !unchanged(&box.after, sizeof box.after))
            return 21;
    }
    for (size_t i = 0; i < sizeof overflow / sizeof overflow[0]; ++i) {
        struct boxed box;
        fill(&box, sizeof box);
        errno = TEST_ERRNO;
        if (gmtime_r(&overflow[i], &box.result) || errno != EOVERFLOW ||
            !unchanged(&box.before, sizeof box.before) || !unchanged(&box.after, sizeof box.after))
            return 22;
#ifndef OA_PHASE6_HOST
        if (!unchanged(&box.result, sizeof box.result))
            return 23;
#endif
    }
    return 0;
}

struct difference_case {
    time_t later, earlier;
    uint64_t bits[4];
};

#define ALL(value) {value, value, value, value}
static const struct difference_case differences[] = {
    {LONG_MAX, LONG_MAX - 1, ALL(UINT64_C(0x3ff0000000000000))},
    {LONG_MIN, LONG_MIN + 1, ALL(UINT64_C(0xbff0000000000000))},
    {LONG_MAX, LONG_MAX, ALL(0)},
    {LONG_MAX, LONG_MIN, {UINT64_C(0x43f0000000000000), UINT64_C(0x43efffffffffffff),
                         UINT64_C(0x43f0000000000000), UINT64_C(0x43efffffffffffff)}},
    {LONG_MIN, LONG_MAX, {UINT64_C(0xc3f0000000000000), UINT64_C(0xc3f0000000000000),
                         UINT64_C(0xc3efffffffffffff), UINT64_C(0xc3efffffffffffff)}},
    {(1L << 53) + 1, 0, {UINT64_C(0x4340000000000000), UINT64_C(0x4340000000000000),
                         UINT64_C(0x4340000000000001), UINT64_C(0x4340000000000000)}},
    {0, (1L << 53) + 1, {UINT64_C(0xc340000000000000), UINT64_C(0xc340000000000001),
                         UINT64_C(0xc340000000000000), UINT64_C(0xc340000000000000)}},
};
#undef ALL

static int difference_case(int directed)
{
    unsigned int original;
    unsigned short control;
    __asm__ volatile("stmxcsr %0; fnstcw %1" : "=m"(original), "=m"(control));
    for (unsigned mode = 0; mode < (directed ? 4u : 1u); ++mode) {
        unsigned int requested = (original & ~0x6000u) | (mode << 13);
        __asm__ volatile("ldmxcsr %0" : : "m"(requested) : "memory");
        for (size_t i = 0; i < sizeof differences / sizeof differences[0]; ++i) {
#if defined(OA_PHASE6_HOST) && !defined(__GLIBC__)
            time_t later = differences[i].later, earlier = differences[i].earlier;
            if ((later == LONG_MAX && earlier == LONG_MIN) ||
                (later == LONG_MIN && earlier == LONG_MAX))
                continue;
#endif
            errno = TEST_ERRNO;
            union { double value; uint64_t bits; } actual;
            actual.value = difftime(differences[i].later, differences[i].earlier);
            if (actual.bits != differences[i].bits[mode] || errno != TEST_ERRNO) {
                __asm__ volatile("ldmxcsr %0" : : "m"(original) : "memory");
                return 31;
            }
        }
        unsigned int observed;
        unsigned short observed_control;
        __asm__ volatile("stmxcsr %0; fnstcw %1" : "=m"(observed), "=m"(observed_control));
        if ((observed & ~0x3fu) != (requested & ~0x3fu) || observed_control != control) {
            __asm__ volatile("ldmxcsr %0" : : "m"(original) : "memory");
            return 32;
        }
    }
    __asm__ volatile("ldmxcsr %0" : : "m"(original) : "memory");
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    const char *mode = argv[1];
    if (same_text(mode, "gmtime")) return utc_case();
    if (same_text(mode, "gmtime-r")) return reentrant_case();
    if (same_text(mode, "difftime")) return difference_case(0);
    if (same_text(mode, "difftime-directed")) return difference_case(1);
    return 2;
}
