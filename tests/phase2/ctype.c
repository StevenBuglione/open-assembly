#include <ctype.h>
#include <stdio.h>

#include "test.h"

#if TEST_FUNCTION_ID == 23
# define TEST_NAME isalnum
#elif TEST_FUNCTION_ID == 24
# define TEST_NAME isalpha
#elif TEST_FUNCTION_ID == 25
# define TEST_NAME isblank
#elif TEST_FUNCTION_ID == 26
# define TEST_NAME iscntrl
#elif TEST_FUNCTION_ID == 27
# define TEST_NAME isdigit
#elif TEST_FUNCTION_ID == 28
# define TEST_NAME isgraph
#elif TEST_FUNCTION_ID == 29
# define TEST_NAME islower
#elif TEST_FUNCTION_ID == 30
# define TEST_NAME isprint
#elif TEST_FUNCTION_ID == 31
# define TEST_NAME ispunct
#elif TEST_FUNCTION_ID == 32
# define TEST_NAME isspace
#elif TEST_FUNCTION_ID == 33
# define TEST_NAME isupper
#elif TEST_FUNCTION_ID == 34
# define TEST_NAME isxdigit
#elif TEST_FUNCTION_ID == 35
# define TEST_NAME tolower
#elif TEST_FUNCTION_ID == 36
# define TEST_NAME toupper
#else
# error unsupported ctype function ID
#endif

extern __typeof__(TEST_NAME) CANDIDATE;
static __typeof__(TEST_NAME) *volatile host = TEST_NAME;

static int abi(void)
{
    int status = ABI_CALL(UINT64_C(0xdeadbeefffffffff));
    if (status)
        return status;
    return ABI_CALL(UINT64_C(0xabad1dea00000041));
}

static int classification(int c)
{
    /* C17 §7.4 and the x86-64 C locale's ASCII execution character set. */
    int digit = c >= '0' && c <= '9';
    int upper = c >= 'A' && c <= 'Z';
    int lower = c >= 'a' && c <= 'z';
    int graph = c >= 0x21 && c <= 0x7e;
    switch (TEST_FUNCTION_ID) {
    case 23: return digit || upper || lower;
    case 24: return upper || lower;
    case 25: return c == '\t' || c == ' ';
    case 26: return (c >= 0 && c <= 0x1f) || c == 0x7f;
    case 27: return digit;
    case 28: return graph;
    case 29: return lower;
    case 30: return c >= 0x20 && c <= 0x7e;
    case 31: return graph && !(digit || upper || lower);
    case 32: return c == ' ' || (c >= '\t' && c <= '\r');
    case 33: return upper;
    case 34: return digit || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f');
    case 35: return upper ? c + ('a' - 'A') : c;
    case 36: return lower ? c - ('a' - 'A') : c;
    }
    return 0;
}

static int normalized(int value)
{
    return TEST_FUNCTION_ID >= 35 ? value : !!value;
}

static int sample(size_t index, uint32_t *state, int compare_host)
{
    unsigned code = index < 257 ? (unsigned)index : phase2_next(state) % 257;
    int c = code == 256 ? EOF : (int)code;
    int expected = classification(c);
    if (compare_host && normalized(host(c)) != expected)
        return phase2_error("host C locale differed for input %d", c);
    int actual = normalized(CANDIDATE(c));
    if (actual != expected)
        return phase2_fail("input %d expected %d got %d", c, expected, actual);
    return 0;
}

const struct phase2_fixture fixture = {
    STR(TEST_NAME), "c17:c-locale-ctype", NULL, NULL, 257,
    abi, NULL, sample,
};
