#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <stdlib.h>

#include "test.h"

#if TEST_FUNCTION_ID == 37
# define TEST_NAME atoi
#elif TEST_FUNCTION_ID == 38
# define TEST_NAME atol
#elif TEST_FUNCTION_ID == 39
# define TEST_NAME atoll
#elif TEST_FUNCTION_ID == 40
# define TEST_NAME strtol
#elif TEST_FUNCTION_ID == 41
# define TEST_NAME strtoll
#elif TEST_FUNCTION_ID == 42
# define TEST_NAME strtoul
#elif TEST_FUNCTION_ID == 43
# define TEST_NAME strtoull
#elif TEST_FUNCTION_ID == 44
# define TEST_NAME strtoimax
#elif TEST_FUNCTION_ID == 45
# define TEST_NAME strtoumax
#else
# error unsupported integer conversion ID
#endif

#define SIMPLE (TEST_FUNCTION_ID <= 39)
#define UNSIGNED_RESULT (TEST_FUNCTION_ID == 42 || TEST_FUNCTION_ID == 43 || TEST_FUNCTION_ID == 45)

extern __typeof__(TEST_NAME) CANDIDATE;
static __typeof__(TEST_NAME) *volatile host = TEST_NAME;

typedef unsigned __int128 wide;

enum kind { NUMBER, NO_DIGITS, INVALID_BASE };
enum { ERRNO_SENTINEL = 1031, INPUT_SIZE = 160 };

struct vector {
    const char *input;
    int base;
    size_t end;
    wide magnitude;
    int negative;
    enum kind kind;
};

static const struct vector lexical[] = {
    {"", 10, 0, 0, 0, NO_DIGITS},
    {" \t\n\r\v\f", 10, 0, 0, 0, NO_DIGITS},
    {"  -", 10, 0, 0, 0, NO_DIGITS},
    {"+-1", 10, 0, 0, 0, NO_DIGITS},
    {"\x0e" "123", 10, 0, 0, 0, NO_DIGITS},
    {"\xff" "123", 10, 0, 0, 0, NO_DIGITS},
    {" \t+42x", 10, 5, 42, 0, NUMBER},
    {"\n-0057.2", 10, 6, 57, 1, NUMBER},
    {"-0", 10, 2, 0, 1, NUMBER},
    {"010", 10, 3, 10, 0, NUMBER},
    {"0x17", 10, 1, 0, 0, NUMBER},
#if !SIMPLE
    {"0128", 0, 3, 10, 0, NUMBER},
    {" \t-0x7Fz", 0, 7, 127, 1, NUMBER},
    {"0X", 0, 1, 0, 0, NUMBER},
    {"-0x", 16, 2, 0, 1, NUMBER},
    {"0x+f", 16, 1, 0, 0, NUMBER},
    {"0x:", 0, 1, 0, 0, NUMBER},
    {"0x:", 16, 1, 0, 0, NUMBER},
    {"0XG", 16, 1, 0, 0, NUMBER},
    {"\t+0XfF?", 16, 6, 255, 0, NUMBER},
    {"0b101", 0, 1, 0, 0, NUMBER},
    {"0B101", 2, 1, 0, 0, NUMBER},
    {"A", 10, 0, 0, 0, NO_DIGITS},
    {"2", 2, 0, 0, 0, NO_DIGITS},
    {":", 16, 0, 0, 0, NO_DIGITS},
    {":", 36, 0, 0, 0, NO_DIGITS},
    {"[", 36, 0, 0, 0, NO_DIGITS},
    {"{", 36, 0, 0, 0, NO_DIGITS},
    {"@", 10, 0, 0, 0, NO_DIGITS},
    {"`", 10, 0, 0, 0, NO_DIGITS},
    {"@", 36, 0, 0, 0, NO_DIGITS},
    {"`", 36, 0, 0, 0, NO_DIGITS},
    {"A@", 36, 1, 10, 0, NUMBER},
    {"z`", 36, 1, 35, 0, NUMBER},
    {"zZ?", 36, 2, 1295, 0, NUMBER},
    {"10102", 2, 4, 10, 0, NUMBER},
    {"-17", -1, 0, 0, 0, INVALID_BASE},
    {"-17", 1, 0, 0, 0, INVALID_BASE},
    {"0", 1, 0, 0, 0, INVALID_BASE},
    {"-17", 37, 0, 0, 0, INVALID_BASE},
    {"-17", INT_MIN, 0, 0, 0, INVALID_BASE},
    {"-17", INT_MAX, 0, 0, 0, INVALID_BASE},
    {"184467440737095516160000tail", 10, 24, (wide)UINT64_MAX + 1, 0, NUMBER},
    {"-184467440737095516160000tail", 10, 25, (wide)UINT64_MAX + 1, 1, NUMBER},
#endif
};

static int abi(void)
{
    const char input[] = "\t-0xfz";
    char *end = NULL;
    return ABI_CALL(ADDRESS(input), ADDRESS(&end), UINT64_C(0xdeadbeef00000010));
}

static uint64_t expected_value(const struct vector *v, int *error)
{
    *error = ERRNO_SENTINEL;
    if (v->kind != NUMBER) {
        if (!SIMPLE)
            *error = EINVAL;
        return 0;
    }
    uint64_t max = UNSIGNED_RESULT ? UINT64_MAX : TEST_FUNCTION_ID == 37 ? INT_MAX : INT64_MAX;
    uint64_t limit = max + (unsigned)(!UNSIGNED_RESULT && v->negative);
    if (v->magnitude > limit) {
        *error = ERANGE;
        return v->negative && !UNSIGNED_RESULT ? UINT64_C(0) - limit : max;
    }
    uint64_t magnitude = (uint64_t)v->magnitude;
    return v->negative ? UINT64_C(0) - magnitude : magnitude;
}

static int trial(const struct vector *v, int compare_host, int check_null_end)
{
    int expected_errno;
    uint64_t expected = expected_value(v, &expected_errno);
#if SIMPLE
    (void)check_null_end;
    if (compare_host && (uint64_t)host(v->input) != expected)
        return phase2_error("host decimal conversion disagreed with constructed value");
    errno = ERRNO_SENTINEL;
    uint64_t actual = (uint64_t)CANDIDATE(v->input);
    if (actual != expected || errno != expected_errno)
        return phase2_fail("input %s returned %#" PRIx64 " errno %d expected %#" PRIx64 " errno %d",
                           v->input, actual, errno, expected, expected_errno);
#else
    if (compare_host && v->kind != INVALID_BASE) {
        char *end = NULL;
        errno = ERRNO_SENTINEL;
        uint64_t actual = (uint64_t)host(v->input, &end, v->base);
        if (actual != expected || end != v->input + v->end
                || (expected_errno == ERANGE && errno != ERANGE))
            return phase2_error("host base %d disagreed with constructed value or end position", v->base);
    }
    char *end = NULL;
    errno = ERRNO_SENTINEL;
    uint64_t actual = (uint64_t)CANDIDATE(v->input, &end, v->base);
    if (actual != expected || end != v->input + v->end || errno != expected_errno)
        return phase2_fail("base %d input %s returned %#" PRIx64 " end %p errno %d expected %#" PRIx64
                           " end +%zu errno %d", v->base, v->input, actual, (void *)end, errno,
                           expected, v->end, expected_errno);
    if (check_null_end) {
        errno = ERRNO_SENTINEL;
        if ((uint64_t)CANDIDATE(v->input, NULL, v->base) != expected || errno != expected_errno)
            return phase2_fail("NULL end pointer changed result or errno in base %d", v->base);
    }
#endif
    return 0;
}

static struct vector generated(char text[INPUT_SIZE], size_t index, uint32_t *state)
{
    int base = SIMPLE ? 10 : (int)(2 + index % 35);
    unsigned radix = (unsigned)base;
    if (!SIMPLE && index % 4 == 0) {
        static const unsigned detected[] = {8, 10, 16};
        base = 0;
        radix = detected[(index / 4) % 3];
    }
    int negative = (index % 2) != 0;
    uint64_t max = UNSIGNED_RESULT ? UINT64_MAX : TEST_FUNCTION_ID == 37 ? INT_MAX : INT64_MAX;
    uint64_t limit = max + (unsigned)(!UNSIGNED_RESULT && negative);
    wide magnitude;
    switch (index % 11) {
    case 0: magnitude = 0; break;
    case 1: magnitude = 1; break;
    case 2: magnitude = limit; break;
    case 3: magnitude = limit - 1; break;
    case 4: magnitude = (wide)limit + !SIMPLE; break;
    case 5: magnitude = SIMPLE ? limit : (wide)UINT64_MAX + 1; break;
    default: {
        uint64_t high = phase2_next(state);
        uint64_t random = (high << 32) | phase2_next(state);
        magnitude = SIMPLE ? random % limit : random;
        break;
    }
    }

    static const char whitespace[] = " \t\n\r\v\f";
    size_t position = index % sizeof whitespace;
    for (size_t i = 0; i < position; ++i)
        text[i] = whitespace[i];
    if (negative)
        text[position++] = '-';
    else if (index % 3 == 0)
        text[position++] = '+';
    if (base == 0 && radix == 8)
        text[position++] = '0';
    if (radix == 16 && (base == 0 || index % 3 == 0)) {
        text[position++] = '0';
        text[position++] = index % 2 ? 'X' : 'x';
    }
    char reversed[130];
    size_t count = 0;
    wide remaining = magnitude;
    do {
        unsigned digit = (unsigned)(remaining % radix);
        reversed[count] = digit < 10 ? (char)('0' + digit)
            : (char)(((index + count) % 2 ? 'A' : 'a') + digit - 10);
        ++count;
        remaining /= radix;
    } while (remaining);
    while (count)
        text[position++] = reversed[--count];
    text[position] = '?';
    text[position + 1] = '\0';
    return (struct vector){text, base, position, magnitude, negative, NUMBER};
}

static int sample(size_t index, uint32_t *state, int compare_host)
{
    char text[INPUT_SIZE];
    size_t fixed = sizeof lexical / sizeof lexical[0];
    struct vector v = index < fixed ? lexical[index] : generated(text, index - fixed, state);
    return trial(&v, compare_host, index % 4 == 0);
}

static int guard(void)
{
    struct phase2_page page;
    if (phase2_page_open(&page))
        return 2;
    int status = 0;
    for (size_t i = 0; !status && i < sizeof lexical / sizeof lexical[0]; ++i) {
        for (int high = 0; !status && high <= 1; ++high) {
            struct vector v = lexical[i];
            size_t length = 0;
            while (v.input[length])
                ++length;
            char *input = (char *)edge(&page, length + 1, high);
            for (size_t j = 0; j <= length; ++j)
                input[j] = v.input[j];
            v.input = input;
            if (phase2_page_protect(&page, 1))
                return 2;
            status = trial(&v, 0, 1);
            if (phase2_page_protect(&page, 0))
                return 2;
        }
    }
    if (phase2_page_close(&page))
        return 2;
    return status;
}

const struct phase2_fixture fixture = {
    STR(TEST_NAME), "reference:integer-construction", "reference:page-protection", NULL, 512,
    abi, guard, sample,
};
