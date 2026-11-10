#include <limits.h>
#include <stdlib.h>

#include "test.h"

#if TEST_FUNCTION_ID == 46
# define TEST_NAME qsort
#elif TEST_FUNCTION_ID == 47
# define TEST_NAME bsearch
#else
# error unsupported array algorithm ID
#endif

#define SORT (TEST_FUNCTION_ID == 46)
extern __typeof__(TEST_NAME) CANDIDATE;
static __typeof__(TEST_NAME) *volatile host = TEST_NAME;

enum { MAX_COUNT = 96, MAX_WIDTH = 32, CAPACITY = MAX_COUNT * MAX_WIDTH };

struct comparator_state {
    const unsigned char *base;
    const unsigned char *key;
    size_t count, width, calls;
    int inconsistent, nested, bad;
};

static struct comparator_state compare_state;

static int element(const void *pointer)
{
    uintptr_t base = ADDRESS(compare_state.base), address = ADDRESS(pointer);
    return address >= base && address - base < compare_state.count * compare_state.width
        && (address - base) % compare_state.width == 0;
}

static int key_order(const void *left, const void *right)
{
    unsigned char a = *(const unsigned char *)left;
    unsigned char b = *(const unsigned char *)right;
    return a < b ? INT_MIN : a > b ? INT_MAX : 0;
}

static int comparator(const void *left, const void *right)
{
    unsigned long flags;
    __asm__ volatile ("pushfq; popq %0; cld" : "=r" (flags) : : "cc");
    ++compare_state.calls;
    if ((flags & (1UL << 10)) || (ADDRESS(__builtin_frame_address(0)) & 15)
            || (SORT ? !element(left) : left != compare_state.key) || !element(right)) {
        compare_state.bad = 1;
        return 0;
    }
#if SORT
    if (compare_state.nested) {
        compare_state.nested = 0;
        struct comparator_state outer = compare_state;
        unsigned char nested[] = {4, 1, 3};
        compare_state = (struct comparator_state){.base = nested, .count = 3, .width = 1};
        CANDIDATE(nested, 3, 1, comparator);
        if (compare_state.bad || nested[0] != 1 || nested[1] != 3 || nested[2] != 4)
            outer.bad = 1;
        compare_state = outer;
    }
#endif
    if (compare_state.inconsistent == 1)
        return INT_MAX;
    if (compare_state.inconsistent == 2)
        return compare_state.calls % 2 ? INT_MIN : INT_MAX;
    return key_order(left, right);
}

static int abi(void)
{
    unsigned char data[] = {1, 3, 2, 4};
    const unsigned char key = 2;
    compare_state = (struct comparator_state){.base = data, .key = &key, .count = 4, .width = 1};
#if SORT
    int status = ABI_CALL(ADDRESS(data), sizeof data, 1, ADDRESS(comparator));
#else
    data[1] = 2;
    data[2] = 3;
    int status = ABI_CALL(ADDRESS(&key), ADDRESS(data), sizeof data, 1, ADDRESS(comparator));
#endif
    if (!status && compare_state.bad)
        return phase2_fail("comparator call did not follow the AMD64 ABI or array domain");
    return status;
}

#if SORT
static int ordered_permutation(const unsigned char *result, const unsigned char *original,
                               size_t count, size_t width, int ordered)
{
    unsigned char consumed[MAX_COUNT] = {0};
    for (size_t i = 0; i < count; ++i) {
        if (ordered && i && result[(i - 1) * width] > result[i * width])
            return 0;
        size_t match;
        for (match = 0; match < count; ++match) {
            if (!consumed[match] && equal_bytes(result + i * width, original + match * width, width))
                break;
        }
        if (match == count)
            return 0;
        consumed[match] = 1;
    }
    return 1;
}
#endif

static int trial(unsigned char *data, size_t count, size_t width, const unsigned char *key,
                 int inconsistent, int nested, int compare_host)
{
    size_t bytes = count * width;
    unsigned char original[CAPACITY];
    for (size_t i = 0; i < bytes; ++i)
        original[i] = data[i];
    struct comparator_state initial = {
        .base = data, .key = key, .count = count, .width = width,
        .inconsistent = inconsistent, .nested = nested,
    };

#if SORT
    if (compare_host && width && count > 1 && !inconsistent) {
        unsigned char reference[CAPACITY];
        for (size_t i = 0; i < bytes; ++i)
            reference[i] = original[i];
        host(reference, count, width, key_order);
        if (!ordered_permutation(reference, original, count, width, 1))
            return phase2_error("host qsort did not produce an ordered permutation");
    }
    compare_state = initial;
    CANDIDATE(data, count, width, comparator);
    if (compare_state.bad)
        return phase2_fail("comparator received an invalid pointer or call frame");
    if (count < 2 || !width) {
        if (compare_state.calls || !equal_bytes(data, original, bytes))
            return phase2_fail("degenerate sort called comparator or changed its array");
    } else if (!ordered_permutation(data, original, count, width, !inconsistent)) {
        return phase2_fail("count=%zu width=%zu did not produce the expected permutation", count, width);
    }
#else
    int found = 0;
    if (width)
        for (size_t i = 0; i < count; ++i)
            found |= original[i * width] == *key;
    if (compare_host && width && count && !inconsistent) {
        compare_state = initial;
        const unsigned char *reference = host(key, data, count, width, key_order);
        if (!!reference != found || (reference && (!element(reference) || *reference != *key)))
            return phase2_error("host bsearch differed from array membership");
    }
    compare_state = initial;
    const unsigned char *result = CANDIDATE(key, data, count, width, comparator);
    if (compare_state.bad)
        return phase2_fail("comparator did not receive key first and an array element second");
    if (!width || !count) {
        if (result || compare_state.calls)
            return phase2_fail("degenerate search returned a match or called comparator");
    } else if ((result && !element(result)) || (!inconsistent && (!!result != found || (result && *result != *key)))) {
        return phase2_fail("count=%zu width=%zu key=%u result does not match array membership", count, width, *key);
    }
    if (!equal_bytes(data, original, bytes))
        return phase2_fail("search modified the input array");
#endif
    return 0;
}

static void generate(unsigned char *data, size_t count, size_t width, size_t index, uint32_t *state)
{
    if (!width)
        return;
    for (size_t i = 0; i < count; ++i) {
        unsigned char *item = data + i * width;
        for (size_t j = 0; j < width; ++j)
            item[j] = (unsigned char)phase2_next(state);
#if SORT
        switch (index % 5) {
        case 0: item[0] = 71; break;
        case 1: item[0] = (unsigned char)i; break;
        case 2: item[0] = (unsigned char)(count - i); break;
        case 3: item[0] = (unsigned char)(i % 2 ? 0xff : 0x80); break;
        default: item[0] &= 7; break;
        }
#else
        item[0] = (unsigned char)(2 * (i / (1 + index % 4)) + 2);
#endif
    }
}

static int sample(size_t index, uint32_t *state, int compare_host)
{
    static const size_t widths[] = {0, 1, 2, 3, 5, 7, 8, 16, 19, 32};
    size_t width = widths[index % (sizeof widths / sizeof widths[0])];
    size_t count = index < 20 ? index / 10 : phase2_next(state) % (MAX_COUNT + 1);
    unsigned char storage[CAPACITY + 35];
    size_t offset = 1 + index % 33;
    unsigned char *data = storage + offset;
    for (size_t i = 0; i < sizeof storage; ++i)
        storage[i] = 0xa5;
    generate(data, count, width, index, state);
    unsigned char key = index % 4 == 0 ? 0xff : (unsigned char)(index % 194);
    if (index % 4 == 1 && width && count)
        key = data[(phase2_next(state) % count) * width];
    int inconsistent = index % 17 == 0 ? 1 : index % 19 == 0 ? 2 : 0;
    int status = trial(data, count, width, &key, inconsistent, SORT && index % 31 == 0, compare_host);
    for (size_t i = 0; !status && i < sizeof storage; ++i)
        if ((i < offset || i >= offset + count * width) && storage[i] != 0xa5)
            return phase2_fail("modified storage outside array at offset %zu", i);
    return status;
}

static int guard(void)
{
    struct phase2_page page, key_page;
    if (phase2_page_open(&page) || phase2_page_open(&key_page))
        return 2;
    uint32_t state = UINT32_C(0x3a205e11);
    int status = 0;
    for (int high = 0; !status && high <= 1; ++high) {
        for (size_t trial_id = 0; !status && trial_id < 15; ++trial_id) {
            size_t width = trial_id % 5 == 0 ? 0 : 3 + trial_id;
            size_t count = trial_id / 5 == 0 ? trial_id : MAX_COUNT;
            unsigned char *data = edge(&page, count * width, high);
            unsigned char *key = edge(&key_page, 1, !high);
            generate(data, count, width, trial_id, &state);
            *key = count && width ? data[(count / 2) * width] : 9;
            if (!SORT && (phase2_page_protect(&page, 1) || phase2_page_protect(&key_page, 1)))
                return 2;
            status = trial(data, count, width, key, (int)(trial_id % 3), 0, 0);
            if (!SORT && (phase2_page_protect(&page, 0) || phase2_page_protect(&key_page, 0)))
                return 2;
        }
    }
    if (phase2_page_close(&key_page) || phase2_page_close(&page))
        return 2;
    return status;
}

const struct phase2_fixture fixture = {
    STR(TEST_NAME), SORT ? "reference:sorted-permutation" : "reference:sorted-search",
    "reference:page-protection", NULL, 256, abi, guard, sample,
};
