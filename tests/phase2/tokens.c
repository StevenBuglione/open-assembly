#include <string.h>

#include "test.h"

#define TEST_NAME strtok
extern __typeof__(TEST_NAME) CANDIDATE;
static __typeof__(TEST_NAME) *volatile host = TEST_NAME;

enum { MAX_BYTES = 128 };

static int abi(void)
{
    char text[] = ",one;;two";
    const char separators[] = ",;";
    int status = ABI_CALL(ADDRESS(text), ADDRESS(separators));
    if (status)
        return status;
    return ABI_CALL(0, ADDRESS(separators));
}

static int contains(const char *delimiters, char value)
{
    for (; *delimiters; ++delimiters)
        if (*delimiters == value)
            return 1;
    return 0;
}

static int check_tokens(char *input, size_t length, const char *const *sets, size_t count,
                        int is_host)
{
    char expected[MAX_BYTES];
    for (size_t i = 0; i <= length; ++i)
        expected[i] = input[i];

    size_t cursor = 0;
    for (size_t step = 0; step < length + 2; ++step) {
        const char *set = sets[step % count];
        while (cursor < length && contains(set, expected[cursor]))
            ++cursor;
        size_t start = cursor;
        while (cursor < length && !contains(set, expected[cursor]))
            ++cursor;
        if (cursor < length)
            expected[cursor++] = '\0';

        char *start_input = step ? NULL : input;
        char *actual = is_host ? host(start_input, set) : CANDIDATE(start_input, set);
        char *wanted = start < length ? input + start : NULL;
        if (actual != wanted || !equal_bytes(input, expected, length + 1)) {
            if (is_host)
                return phase2_error("host token or mutation differed at step %zu", step);
            return phase2_fail("token pointer or buffer mutation differed at step %zu", step);
        }
    }
    return 0;
}

static int sample(size_t index, uint32_t *state, int compare_host)
{
    if (index == 0) {
        char abandoned[] = "first,abandoned";
        char reset[] = "next,rest";
        if (CANDIDATE(abandoned, ",") != abandoned || CANDIDATE(reset, ",") != reset
                || CANDIDATE(NULL, ",") != reset + 5 || CANDIDATE(NULL, ","))
            return phase2_fail("new input failed to reset unfinished token state");
    }

    static const char alphabet[] = "a,b;;c::::dd\xff" "e";
    static const char *const sets[] = {",;", ":", ";\xff", "", "abc,;:"};
    size_t length = index < 64 ? index : phase2_next(state) % MAX_BYTES;
    char actual[MAX_BYTES], reference[MAX_BYTES];
    for (size_t i = 0; i < length; ++i) {
        size_t choice = index % 3 ? phase2_next(state) % (sizeof alphabet - 1)
                                  : i % (sizeof alphabet - 1);
        actual[i] = reference[i] = alphabet[choice];
    }
    actual[length] = reference[length] = '\0';
    size_t count = 1 + index % (sizeof sets / sizeof sets[0]);
    if (compare_host) {
        int status = check_tokens(reference, length, sets, count, 1);
        if (status)
            return status;
    }
    return check_tokens(actual, length, sets, count, 0);
}

static int guard(void)
{
    struct phase2_page text, separators;
    if (phase2_page_open(&text) || phase2_page_open(&separators))
        return 2;
    static const char sentence[] = ",,one;;two,three;;";
    int status = 0;
    for (int high = 0; !status && high <= 1; ++high) {
        char *input = (char *)edge(&text, sizeof sentence, high);
        char *set = (char *)edge(&separators, 3, high);
        for (size_t i = 0; i < sizeof sentence; ++i)
            input[i] = sentence[i];
        set[0] = ',';
        set[1] = ';';
        set[2] = '\0';
        if (phase2_page_protect(&separators, 1))
            return 2;
        const char *const sets[] = {set};
        status = check_tokens(input, sizeof sentence - 1, sets, 1, 0);
        if (phase2_page_protect(&separators, 0))
            return 2;
    }
    if (phase2_page_close(&text) || phase2_page_close(&separators))
        return 2;
    return status;
}

const struct phase2_fixture fixture = {
    "strtok", "c17:tokenization", "reference:page-protection", NULL, 128,
    abi, guard, sample,
};
