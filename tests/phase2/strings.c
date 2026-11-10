#include <string.h>

#include "test.h"

#if TEST_FUNCTION_ID == 7
# define TEST_NAME strcpy
#elif TEST_FUNCTION_ID == 8
# define TEST_NAME strncpy
#elif TEST_FUNCTION_ID == 9
# define TEST_NAME strcat
#elif TEST_FUNCTION_ID == 10
# define TEST_NAME strncat
#elif TEST_FUNCTION_ID == 11
# define TEST_NAME strcmp
#elif TEST_FUNCTION_ID == 12
# define TEST_NAME strncmp
#elif TEST_FUNCTION_ID == 13
# define TEST_NAME strcoll
#elif TEST_FUNCTION_ID == 14
# define TEST_NAME strxfrm
#elif TEST_FUNCTION_ID == 15
# define TEST_NAME strchr
#elif TEST_FUNCTION_ID == 16
# define TEST_NAME strrchr
#elif TEST_FUNCTION_ID == 17
# define TEST_NAME strcspn
#elif TEST_FUNCTION_ID == 18
# define TEST_NAME strpbrk
#elif TEST_FUNCTION_ID == 19
# define TEST_NAME strspn
#elif TEST_FUNCTION_ID == 20
# define TEST_NAME strstr
#else
# error unsupported string function ID
#endif

extern __typeof__(TEST_NAME) CANDIDATE;
static __typeof__(TEST_NAME) *volatile host = TEST_NAME;

#define WRITES (TEST_FUNCTION_ID <= 10 || TEST_FUNCTION_ID == 14)
#define APPENDS (TEST_FUNCTION_ID == 9 || TEST_FUNCTION_ID == 10)
#define BOUNDED (TEST_FUNCTION_ID == 8 || TEST_FUNCTION_ID == 10 || TEST_FUNCTION_ID == 12)

enum { MAX_LENGTH = 128, STORAGE = 272 };
static const size_t lengths[] = {0, 1, 2, 3, 7, 8, 9, 15, 16, 17, 31, 32, 33,
                                 63, 64, 65, 127, 128};

struct example {
    char *dest;
    const char *a;
    const char *b;
    size_t a_len;
    size_t b_len;
    size_t n;
    int byte;
};

static int abi(void)
{
    const char a[] = "x\xff";
    char b[12] = "y";
#if TEST_FUNCTION_ID == 15 || TEST_FUNCTION_ID == 16
    (void)b;
    return ABI_CALL(ADDRESS(a), UINT64_C(0xdeadbeef00ff00ff));
#elif WRITES
    return ABI_CALL(ADDRESS(b), ADDRESS(a), sizeof a);
#else
    return ABI_CALL(ADDRESS(a), ADDRESS(b), sizeof a);
#endif
}

#if WRITES
static size_t write_size(const struct example *test)
{
    size_t prefix = APPENDS ? test->b_len : 0;
    switch (TEST_FUNCTION_ID) {
    case 8: return test->n;
    case 10: return prefix + (test->n < test->a_len ? test->n : test->a_len) + 1;
    case 14: return test->n > test->a_len ? test->a_len + 1 : 0;
    default: return prefix + test->a_len + 1;
    }
}

static int trial(const struct example *test, int compare_host)
{
    size_t extent = write_size(test), prefix = APPENDS ? test->b_len : 0;
    char expected[STORAGE];
    for (size_t i = 0; i < extent; ++i) {
        if (i < prefix)
            expected[i] = test->b[i];
        else if (i - prefix < test->a_len && (TEST_FUNCTION_ID != 10 || i - prefix < test->n))
            expected[i] = test->a[i - prefix];
        else
            expected[i] = '\0';
    }
    if (compare_host) {
        char reference[STORAGE] = {0};
        if (APPENDS)
            for (size_t i = 0; i <= prefix; ++i)
                reference[i] = test->b[i];
# if TEST_FUNCTION_ID == 14
        if (host(reference, test->a, test->n) != test->a_len)
            return phase2_error("host transformation length differs");
# elif BOUNDED
        if (host(reference, test->a, test->n) != reference)
            return phase2_error("host did not return destination");
# else
        if (host(reference, test->a) != reference)
            return phase2_error("host did not return destination");
# endif
        if (!equal_bytes(reference, expected, extent))
            return phase2_error("host output differs from expected bytes");
    }

# if TEST_FUNCTION_ID == 14
    size_t actual = CANDIDATE(test->dest, test->a, test->n);
    if (actual != test->a_len)
        return phase2_fail("transform returned %zu expected %zu", actual, test->a_len);
# elif BOUNDED
    if (CANDIDATE(test->dest, test->a, test->n) != test->dest)
        return phase2_fail("bounded copy or append did not return destination");
# else
    if (CANDIDATE(test->dest, test->a) != test->dest)
        return phase2_fail("copy or append did not return destination");
# endif
    if (!equal_bytes(test->dest, expected, extent))
        return phase2_fail("output mismatch for source length %zu destination prefix %zu limit %zu",
                           test->a_len, prefix, test->n);
    return 0;
}
#else
static int has_byte(const char *set, size_t size, char value)
{
    for (size_t i = 0; i < size; ++i)
        if (set[i] == value)
            return 1;
    return 0;
}

static int trial(const struct example *test, int compare_host)
{
    const char *a = test->a, *b = test->b;
    size_t an = test->a_len, bn = test->b_len;
    /* Each condition is constant for the selected public symbol. */
    (void)has_byte;
    (void)an;
    (void)bn;
    (void)b;
# if TEST_FUNCTION_ID >= 11 && TEST_FUNCTION_ID <= 13
    size_t n = TEST_FUNCTION_ID == 12 ? test->n : (an < bn ? an : bn) + 1;
    int expected = 0;
    for (size_t i = 0; i < n; ++i) {
        expected = sign_of((unsigned char)a[i] - (unsigned char)b[i]);
        if (expected || !a[i])
            break;
    }
#  if TEST_FUNCTION_ID == 12
    int reference = compare_host ? sign_of(host(a, b, n)) : expected;
    int actual = sign_of(CANDIDATE(a, b, n));
#  else
    int reference = compare_host ? sign_of(host(a, b)) : expected;
    int actual = sign_of(CANDIDATE(a, b));
#  endif
# elif TEST_FUNCTION_ID == 15 || TEST_FUNCTION_ID == 16
    const char *expected = NULL;
    for (size_t i = 0; i <= an; ++i) {
        if (a[i] == (char)test->byte) {
            expected = a + i;
            if (TEST_FUNCTION_ID == 15)
                break;
        }
    }
    const char *reference = compare_host ? host(a, test->byte) : expected;
    const char *actual = CANDIDATE(a, test->byte);
# elif TEST_FUNCTION_ID >= 17 && TEST_FUNCTION_ID <= 19
    size_t offset = 0;
    while (offset < an && has_byte(b, bn, a[offset]) == (TEST_FUNCTION_ID == 19))
        ++offset;
#  if TEST_FUNCTION_ID == 18
    const char *expected = offset < an ? a + offset : NULL;
    const char *reference = compare_host ? host(a, b) : expected;
    const char *actual = CANDIDATE(a, b);
#  else
    size_t expected = offset;
    size_t reference = compare_host ? host(a, b) : expected;
    size_t actual = CANDIDATE(a, b);
#  endif
# else
    const char *expected = NULL;
    for (size_t i = 0; i + bn <= an; ++i) {
        if (equal_bytes(a + i, b, bn)) {
            expected = a + i;
            break;
        }
    }
    const char *reference = compare_host ? host(a, b) : expected;
    const char *actual = CANDIDATE(a, b);
# endif
    if (reference != expected)
        return phase2_error("host disagreed with the string reference calculation");
    if (actual != expected)
        return phase2_fail("lengths %zu/%zu, limit %zu, byte %#x returned %#zx expected %#zx",
                           an, bn, test->n, (unsigned)test->byte, (size_t)actual, (size_t)expected);
    return 0;
}
#endif

static int sample(size_t index, uint32_t *state, int compare_host)
{
    char a[STORAGE], b[STORAGE], dest[STORAGE];
    size_t an = index < 256 ? lengths[index % (sizeof lengths / sizeof lengths[0])]
                            : phase2_next(state) % (MAX_LENGTH + 1);
    size_t bn = phase2_next(state) % (MAX_LENGTH + 1);
    size_t n = phase2_next(state) % (MAX_LENGTH + 2);
    if (index % 4 == 0)
        n = 0;
    if (index % 4 == 1)
        n = an;
    if (index % 4 == 2)
        n = an + 1;
    if (TEST_FUNCTION_ID == 14 && index == 0) {
        /* n is a ceiling on writes, and this complete result fits in dest. */
        an = 17;
        n = SIZE_MAX;
    }
    for (size_t i = 0; i < an; ++i)
        a[i] = (char)(1 + phase2_next(state) % 255);
    for (size_t i = 0; i < bn; ++i)
        b[i] = (char)(1 + phase2_next(state) % 255);
    a[an] = b[bn] = '\0';
    int byte = (int)((phase2_next(state) & UINT32_C(0xffffff00)) | (index & 0xff));
    if (an && index % 2) {
        byte = (int)((unsigned)byte & ~0xffu) | (unsigned char)a[index % an];
        a[an - 1] = (char)byte;
    }
#if TEST_FUNCTION_ID == 11 || TEST_FUNCTION_ID == 12 || TEST_FUNCTION_ID == 13
    if (index % 4 != 0) {
        if (index % 4 <= 2)
            bn = an;
        for (size_t i = 0; i < an && i < bn; ++i)
            b[i] = a[i];
        if (an && index % 4 == 2)
            b[an - 1] = a[an - 1] == (char)0x80 ? (char)0x7f : (char)0x80;
        b[bn] = '\0';
    }
#elif TEST_FUNCTION_ID == 17 || TEST_FUNCTION_ID == 18 || TEST_FUNCTION_ID == 19 || TEST_FUNCTION_ID == 20
    if (index % 4 == 0) {
        b[0] = '\0';
        bn = 0;
    } else if (index % 4 == 1 && an) {
        size_t offset = index % an;
        bn = an - offset;
        for (size_t i = 0; i < bn; ++i)
            b[i] = a[offset + i];
        b[bn] = '\0';
    } else if (index % 4 == 2) {
        an = 8;
        bn = 4;
        for (size_t i = 0; i < an; ++i)
            a[i] = i < an - 1 ? 'a' : 'b';
        for (size_t i = 0; i < bn; ++i)
            b[i] = i < bn - 1 ? 'a' : 'b';
        a[an] = b[bn] = '\0';
    }
#endif
    for (size_t i = 0; i < sizeof dest; ++i)
        dest[i] = APPENDS && i <= bn ? b[i] : (char)0xa5;
    struct example test = {dest, a, b, an, bn, n, byte};
    int status = trial(&test, compare_host);
#if WRITES
    size_t extent = write_size(&test);
    for (size_t i = extent; !status && i < sizeof dest; ++i)
        if (dest[i] != (char)0xa5)
            return phase2_fail("wrote beyond expected output at offset %zu", i);
#endif
    return status;
}

static int guard(void)
{
    struct phase2_page a_page, b_page, dest_page;
    if (phase2_page_open(&a_page) || phase2_page_open(&b_page) || phase2_page_open(&dest_page))
        return 2;
    int status = 0;
    for (size_t i = 0; !status && i < sizeof lengths / sizeof lengths[0]; ++i) {
        for (int high = 0; !status && high <= 1; ++high) {
            size_t an = lengths[i], bn = an / 2;
            size_t n = i % 3 == 0 ? an : an + (i % 3);
#if TEST_FUNCTION_ID == 12
            bn = an;
#endif
            int bounded_a = BOUNDED && n <= an;
            int bounded_b = TEST_FUNCTION_ID == 12 && n <= bn;
            size_t a_extent = bounded_a ? n : an + 1;
            size_t b_extent = bounded_b ? n : bn + 1;
            char *a = (char *)edge(&a_page, a_extent, high);
            char *b = (char *)edge(&b_page, b_extent, high);
            for (size_t j = 0; j < a_extent; ++j)
                a[j] = j == an ? '\0' : (char)(1 + j % 255);
            for (size_t j = 0; j < b_extent; ++j)
                b[j] = j == bn ? '\0' : (char)(1 + j % 255);
#if TEST_FUNCTION_ID == 12
            if (bn && i % 2)
                b[bn - 1] = (char)0xff;
#endif
            if (phase2_page_protect(&a_page, 1) || phase2_page_protect(&b_page, 1))
                return 2;
            struct example test = {NULL, a, b, an, bn, n, 0x100};
#if WRITES
            size_t extent = write_size(&test);
            size_t capacity = TEST_FUNCTION_ID == 14 ? n : extent;
            test.dest = (char *)edge(&dest_page, capacity, high);
            for (size_t j = 0; j < capacity; ++j)
                test.dest[j] = APPENDS && j <= bn ? b[j] : (char)0xa5;
#endif
            status = trial(&test, 0);
#if TEST_FUNCTION_ID == 14
            for (size_t j = extent; !status && j < capacity; ++j)
                if (test.dest[j] != (char)0xa5)
                    status = phase2_fail("changed destination outside transformed bytes");
            if (!status && n == 0) {
                test.dest = NULL;
                status = trial(&test, 0);
            }
#endif
            if (phase2_page_protect(&a_page, 0) || phase2_page_protect(&b_page, 0))
                return 2;
        }
    }
    if (phase2_page_close(&dest_page) || phase2_page_close(&b_page) || phase2_page_close(&a_page))
        return 2;
    return status;
}

const struct phase2_fixture fixture = {
    STR(TEST_NAME), "c17:string-operations", "reference:page-protection", NULL, 256,
    abi, guard, sample,
};
