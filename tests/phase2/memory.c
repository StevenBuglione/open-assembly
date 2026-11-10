#include <string.h>

#include "test.h"

#if TEST_FUNCTION_ID == 2
# define TEST_NAME memcpy
#elif TEST_FUNCTION_ID == 3
# define TEST_NAME memmove
#elif TEST_FUNCTION_ID == 4
# define TEST_NAME memset
#elif TEST_FUNCTION_ID == 5
# define TEST_NAME memcmp
#elif TEST_FUNCTION_ID == 6
# define TEST_NAME memchr
#else
# error unsupported memory function ID
#endif

extern __typeof__(TEST_NAME) CANDIDATE;
static __typeof__(TEST_NAME) *volatile host = TEST_NAME;

enum { MAX_LENGTH = 512, STORAGE = 768 };
static const size_t lengths[] = {0, 1, 2, 3, 7, 8, 9, 15, 16, 17, 31, 32, 33,
                                 63, 64, 65, 127, 128, 129, 255, 256, 257, 511, 512};

static int abi(void)
{
    unsigned char source[9] = {0xff, 0x80, 0x7f};
#if TEST_FUNCTION_ID == 4 || TEST_FUNCTION_ID == 6
    return ABI_CALL(ADDRESS(source), UINT64_C(0xdeadbeef00ff0080), sizeof source);
#else
    unsigned char destination[9] = {0};
    return ABI_CALL(ADDRESS(destination), ADDRESS(source), sizeof source);
#endif
}

static int trial(unsigned char *dst, const unsigned char *src, size_t n, int value, int compare_host)
{
#if TEST_FUNCTION_ID == 5
    (void)value;
    int expected = 0;
    for (size_t i = 0; i < n && !expected; ++i)
        expected = sign_of((int)src[i] - (int)dst[i]);
    if (compare_host && sign_of(host(src, dst, n)) != expected)
        return phase2_error("host comparison disagreed with first differing byte");
    int actual = sign_of(CANDIDATE(src, dst, n));
    if (actual != expected)
        return phase2_fail("n=%zu expected comparison sign %d got %d", n, expected, actual);
#elif TEST_FUNCTION_ID == 6
    (void)dst;
    const unsigned char *expected = NULL;
    for (size_t i = 0; i < n; ++i) {
        if (src[i] == (unsigned char)value) {
            expected = src + i;
            break;
        }
    }
    if (compare_host && host(src, value, n) != expected)
        return phase2_error("host search disagreed with first matching byte");
    const unsigned char *actual = CANDIDATE(src, value, n);
    if (actual != expected)
        return phase2_fail("n=%zu byte=%#x expected %p got %p", n,
                           (unsigned char)value, (const void *)expected, (const void *)actual);
#else
    unsigned char expected[MAX_LENGTH];
# if TEST_FUNCTION_ID == 4
    (void)src;
    for (size_t i = 0; i < n; ++i)
        expected[i] = (unsigned char)value;
    if (compare_host) {
        unsigned char reference[MAX_LENGTH];
        if (host(reference, value, n) != reference || !equal_bytes(reference, expected, n))
            return phase2_error("host fill disagreed with expected byte values");
    }
    void *actual = CANDIDATE(dst, value, n);
# else
    (void)value;
    for (size_t i = 0; i < n; ++i)
        expected[i] = src[i];
    if (compare_host) {
        unsigned char reference[2 * MAX_LENGTH] = {0};
        unsigned char *source = reference;
        unsigned char *destination = reference + MAX_LENGTH;
#  if TEST_FUNCTION_ID == 3
        uintptr_t a = ADDRESS(dst), b = ADDRESS(src);
        if (a >= b && a - b < n)
            destination = source + (a - b);
        if (b > a && b - a < n) {
            destination = reference;
            source = destination + (b - a);
        }
#  endif
        for (size_t i = 0; i < n; ++i)
            source[i] = expected[i];
        if (host(destination, source, n) != destination || !equal_bytes(destination, expected, n))
            return phase2_error("host copy disagreed with original source bytes");
    }
    void *actual = CANDIDATE(dst, src, n);
# endif
    if (actual != dst)
        return phase2_fail("n=%zu returned a pointer other than destination", n);
    if (!equal_bytes(dst, expected, n))
        return phase2_fail("n=%zu destination differs from expected bytes", n);
#endif
    return 0;
}

static int sample(size_t index, uint32_t *state, int compare_host)
{
    unsigned char bytes[STORAGE], other[STORAGE], before[STORAGE];
    for (size_t i = 0; i < STORAGE; ++i) {
        bytes[i] = (unsigned char)phase2_next(state);
        other[i] = (unsigned char)phase2_next(state);
        before[i] = bytes[i];
    }
    size_t n = index < 256 ? lengths[index % (sizeof lengths / sizeof lengths[0])]
                           : phase2_next(state) % (MAX_LENGTH + 1);
    unsigned char *dst = bytes + 40 + phase2_next(state) % 64;
    const unsigned char *src = other + 40 + phase2_next(state) % 64;
    int value = (int)((phase2_next(state) & UINT32_C(0xffffff00)) | (index & 0xffu));
#if TEST_FUNCTION_ID == 3
    int delta = (int)(index % 129) - 64;
    dst = bytes + 128;
    src = dst + delta;
    if (index % 7 == 0)
        src = other + 40;
#elif TEST_FUNCTION_ID == 5
    for (size_t i = 0; i < n; ++i)
        dst[i] = src[i];
    if (n && index % 3 != 0) {
        size_t first = index % 4 == 0 ? n - 1 : phase2_next(state) % n;
        dst[first] ^= 0x80;
    }
#elif TEST_FUNCTION_ID == 6
    unsigned char *haystack = other + 40 + index % 64;
    src = haystack;
    for (size_t i = 0; i < n; ++i)
        if (haystack[i] == (unsigned char)value)
            haystack[i] ^= 0x80;
    if (n && index % 3 != 0) {
        size_t first = index % 4 == 0 ? n - 1 : phase2_next(state) % n;
        haystack[first] = haystack[n - 1] = (unsigned char)value;
    }
#endif
    int status = trial(dst, src, n, value, compare_host);
    if (status)
        return status;
    size_t start = (size_t)(dst - bytes);
    if (!equal_bytes(bytes, before, start)
            || !equal_bytes(dst + n, before + start + n, STORAGE - start - n))
        return phase2_fail("write outside destination extent at offset %zu length %zu", start, n);
    return 0;
}

static int guard(void)
{
    struct phase2_page from, to;
    if (phase2_page_open(&from) || phase2_page_open(&to))
        return 2;
    int status = 0;
    for (size_t i = 0; !status && i < sizeof lengths / sizeof lengths[0]; ++i) {
        size_t n = lengths[i];
        for (int high = 0; !status && high <= 1; ++high) {
            for (int dest_high = 0; !status && dest_high <= 1; ++dest_high) {
                unsigned char *src = edge(&from, n, high);
                unsigned char *dst = edge(&to, n, dest_high);
                for (size_t j = 0; j < n; ++j)
                    src[j] = dst[j] = (unsigned char)(1 + j % 251);
#if TEST_FUNCTION_ID == 5
                if (n && high != dest_high)
                    dst[n - 1] ^= 0x80;
#elif TEST_FUNCTION_ID == 6
                if (n)
                    src[n - 1] = 0xfe;
#endif
                if (phase2_page_protect(&from, 1))
                    return 2;
#if TEST_FUNCTION_ID == 5
                if (phase2_page_protect(&to, 1))
                    return 2;
#endif
                status = trial(dst, src, n, 0x100, 0);
#if TEST_FUNCTION_ID == 6
                if (!status)
                    status = trial(dst, src, n, 0x1fe, 0);
#endif
                if (phase2_page_protect(&from, 0))
                    return 2;
#if TEST_FUNCTION_ID == 5
                if (phase2_page_protect(&to, 0))
                    return 2;
#elif TEST_FUNCTION_ID == 3
                if (!status && n > 1) {
                    unsigned char *span = edge(&to, n + 1, dest_high);
                    for (size_t j = 0; j <= n; ++j)
                        span[j] = (unsigned char)(j ^ 0xa5);
                    status = trial(span + high, span + !high, n, 0, 0);
                }
#endif
            }
        }
    }
    if (phase2_page_close(&to) || phase2_page_close(&from))
        return 2;
    return status;
}

const struct phase2_fixture fixture = {
    STR(TEST_NAME), "c17:byte-operations", "reference:page-protection", NULL, 256,
    abi, guard, sample,
};
