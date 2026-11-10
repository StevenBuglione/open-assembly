#include "fixture.h"

#include <sys/mman.h>

#ifndef OA_PHASE6_HOST
struct aux_entry { unsigned long type, value; };
extern const struct aux_entry *const __al_auxv;
#endif

struct stimulus { uint64_t mode, value; };
struct observed {
    int64_t result;
    uint64_t scenario, text_units, pattern_units, text_length, pattern_length, contents, error;
};
_Static_assert(sizeof(struct stimulus) == 16 && sizeof(struct observed) == 64,
               "Linux LP64 packet widths");

enum { CAPACITY = 160, CANARY = 0x31415926 };
static const unsigned scenarios[OPERATIONS] = {13, 13, 13, 14};

struct problem {
    wchar_t text[CAPACITY], pattern[CAPACITY];
    size_t text_units, pattern_units;
};
struct guard { char *base; size_t page; };
struct array { wchar_t *start, *neighbor; };

static size_t linux_page_size(void)
{
#ifdef OA_PHASE6_HOST
    long size = sysconf(_SC_PAGESIZE);
    return size > 0 ? (size_t)size : 0;
#else
    for (const struct aux_entry *entry = __al_auxv; entry->type; ++entry)
        if (entry->type == 6)
            return entry->value;
    return 0;
#endif
}

static int map_guard(struct guard *guard, size_t page)
{
    long base = kernel_call(__NR_mmap, 0, (long)(3 * page), PROT_NONE,
                            MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (base < 0)
        return 0;
    if (kernel_call(__NR_mprotect, base + (long)page, (long)page, PROT_READ | PROT_WRITE, 0, 0, 0)) {
        (void)kernel_call(__NR_munmap, base, (long)(3 * page), 0, 0, 0, 0);
        return 0;
    }
    *guard = (struct guard){(char *)base, page};
    return 1;
}

static int unmap_guard(const struct guard *guard)
{
    return kernel_call(__NR_munmap, (long)guard->base, (long)(3 * guard->page),
                       0, 0, 0, 0) == 0;
}

static struct array place(const struct guard *guard, size_t units, int right)
{
    if (!units)
        return (struct array){(wchar_t *)guard->base, NULL};
    char *page = guard->base + guard->page;
    wchar_t *start = (wchar_t *)(page + (right ? guard->page - units * sizeof(wchar_t) : 0));
    wchar_t *neighbor = right ? start - 1 : start + units;
    *neighbor = CANARY;
    return (struct array){start, neighbor};
}

static uint32_t random_word(uint64_t *state)
{
    uint64_t value = (*state += UINT64_C(0x9e3779b97f4a7c15));
    value = (value ^ (value >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    value = (value ^ (value >> 27)) * UINT64_C(0x94d049bb133111eb);
    return (uint32_t)(value ^ (value >> 31));
}

static wchar_t nonzero(uint64_t *state)
{
    static const wchar_t values[] = {WCHAR_MIN, WCHAR_MAX, -1, 1, 0x100, 0x10000, 0x1000000};
    uint32_t word = random_word(state);
    unsigned index = word & 15;
    return index < sizeof values / sizeof *values ? values[index] : element(word | 1U);
}

static void assign_words(wchar_t *destination, const wchar_t *source, size_t units)
{
    volatile wchar_t *output = destination;
    for (size_t i = 0; i < units; ++i)
        output[i] = source[i];
}

static void pair(struct problem *problem, const wchar_t *text, size_t text_units,
                 const wchar_t *pattern, size_t pattern_units)
{
    problem->text_units = text_units;
    problem->pattern_units = pattern_units;
    assign_words(problem->text, text, text_units);
    assign_words(problem->pattern, pattern, pattern_units);
}

static void fill_nonzero(wchar_t *words, size_t units, uint64_t *state, wchar_t avoid)
{
    for (size_t i = 0; i < units; ++i) {
        wchar_t word = nonzero(state);
        words[i] = word == avoid ? (avoid == 1 ? 2 : 1) : word;
    }
}

static void membership_problem(struct problem *problem, unsigned mode, uint64_t seed)
{
    static const wchar_t empty[] = {0};
    static const wchar_t minimum[] = {WCHAR_MIN, 0};
    static const wchar_t all[] = {-1, WCHAR_MIN, -1, WCHAR_MAX, 0};
    static const wchar_t base[] = {WCHAR_MIN, -1, WCHAR_MAX, 0};
    static const wchar_t high_a[] = {(wchar_t)(INT32_MIN + 0x5a), 0};
    static const wchar_t high_b[] = {(wchar_t)(INT32_MIN + 0x1005a), 0};
    static const wchar_t tail[] = {1, 0, WCHAR_MIN, 0};
    static const wchar_t first[] = {1, WCHAR_MIN, -1, WCHAR_MIN, 0};
    static const wchar_t two[] = {WCHAR_MIN, -1, 0};
    switch (mode) {
    case 0: pair(problem, empty, 1, empty, 1); return;
    case 1: pair(problem, empty, 1, all, 5); return;
    case 2: pair(problem, base, 4, empty, 1); return;
    case 8: pair(problem, high_a, 2, high_b, 2); return;
    case 9: pair(problem, tail, 4, minimum, 2); return;
    case 10: pair(problem, minimum, 2, tail, 4); return;
    case 12: pair(problem, first, 5, two, 3); return;
    }
    uint64_t state = seed;
    size_t length = 1 + (size_t)(seed & 127);
    if (mode != 3 && length < 2)
        length = 2;
    if (mode == 7 && length < 3)
        length = 3;
    problem->text_units = length + 1;
    problem->text[length] = 0;
    if (mode == 3) {
        assign_words(problem->pattern, all, 5);
        problem->pattern_units = 5;
        for (size_t i = 0; i < length; ++i)
            problem->text[i] = all[(seed + i) % 4];
    } else if (mode == 7) {
        assign_words(problem->pattern, two, 3);
        problem->pattern_units = 3;
        size_t prefix = 1 + (size_t)((seed >> 8) % (length - 1));
        for (size_t i = 0; i < length; ++i)
            problem->text[i] = i < prefix ? two[i % 2] : 1;
    } else if (mode == 11) {
        size_t members = 1 + (size_t)((seed >> 8) & 63);
        problem->pattern_units = members + 1;
        fill_nonzero(problem->pattern, members, &state, 0);
        problem->pattern[members] = 0;
        fill_nonzero(problem->text, length, &state, 0);
        problem->text[(seed >> 16) % length] = problem->pattern[members - 1];
    } else {
        assign_words(problem->pattern, minimum, 2);
        problem->pattern_units = 2;
        fill_nonzero(problem->text, length, &state, WCHAR_MIN);
        if (mode == 4)
            problem->text[0] = WCHAR_MIN;
        else if (mode == 5)
            problem->text[length - 1] = WCHAR_MIN;
    }
}

static void substring_problem(struct problem *problem, unsigned mode, uint64_t seed)
{
    static const wchar_t empty[] = {0};
    static const wchar_t minimum[] = {WCHAR_MIN, 0};
    static const wchar_t base[] = {WCHAR_MIN, -1, 0};
    static const wchar_t short_text[] = {1, -1, 0};
    static const wchar_t long_pattern[] = {1, -1, WCHAR_MIN, 0};
    static const wchar_t repeated[] = {-1, WCHAR_MIN, -1, WCHAR_MIN, -1, 0};
    static const wchar_t pattern[] = {-1, WCHAR_MIN, -1, 0};
    static const wchar_t high_a[] = {(wchar_t)(INT32_MIN + 0x1005a), 0};
    static const wchar_t high_b[] = {(wchar_t)(INT32_MIN + 0x5a), 0};
    static const wchar_t text_tail[] = {1, 0, WCHAR_MIN, -1, 0};
    static const wchar_t tail_pattern[] = {WCHAR_MIN, 0, -1, 0};
    static const wchar_t hay[] = {WCHAR_MIN, WCHAR_MAX, 0};
    static const wchar_t empty_tail[] = {0, WCHAR_MIN, 0};
    switch (mode) {
    case 0: pair(problem, empty, 1, empty, 1); return;
    case 1: pair(problem, empty, 1, minimum, 2); return;
    case 2: pair(problem, base, 3, empty, 1); return;
    case 3: pair(problem, minimum, 2, minimum, 2); return;
    case 4: pair(problem, short_text, 3, long_pattern, 4); return;
    case 8: pair(problem, repeated, 6, pattern, 4); return;
    case 9: pair(problem, high_a, 2, high_b, 2); return;
    case 10: pair(problem, text_tail, 5, base, 3); return;
    case 11: pair(problem, hay, 3, tail_pattern, 4); return;
    case 12: pair(problem, short_text, 3, empty_tail, 3); return;
    }
    uint64_t state = seed;
    if (mode == 5) {
        size_t prefix = 1 + (size_t)(seed % 96);
        size_t length = 1 + (size_t)((seed >> 8) % 31);
        problem->pattern_units = length + 1;
        problem->text_units = prefix + length + 1;
        fill_nonzero(problem->pattern, length, &state, 0);
        problem->pattern[length] = 0;
        fill_nonzero(problem->text, prefix, &state, problem->pattern[0]);
        assign_words(problem->text + prefix, problem->pattern, length + 1);
    } else if (mode == 6 || mode == 7) {
        size_t length = 4 + (size_t)(seed & 63);
        size_t pattern_length = mode == 6 ? 2 + (size_t)((seed >> 8) % (length - 2)) : 2;
        problem->text_units = length + 1;
        problem->pattern_units = pattern_length + 1;
        volatile wchar_t *text = problem->text;
        volatile wchar_t *target = problem->pattern;
        for (size_t i = 0; i < length; ++i)
            text[i] = -1;
        for (size_t i = 0; i < pattern_length; ++i)
            target[i] = -1;
        if (mode == 6)
            problem->text[length - 1] = WCHAR_MIN;
        problem->text[length] = 0;
        problem->pattern[pattern_length - 1] = WCHAR_MIN;
        problem->pattern[pattern_length] = 0;
    } else {
        size_t length = 1 + (size_t)(seed % 112);
        size_t pattern_length = 1 + (size_t)((seed >> 8) & 31);
        problem->text_units = length + 1;
        problem->pattern_units = pattern_length + 1;
        fill_nonzero(problem->text, length, &state, 0);
        fill_nonzero(problem->pattern, pattern_length, &state, 0);
        problem->text[length] = problem->pattern[pattern_length] = 0;
        if ((seed >> 63) && pattern_length <= length) {
            size_t offset = (size_t)((seed >> 16) % (length - pattern_length + 1));
            assign_words(problem->text + offset, problem->pattern, pattern_length);
        }
    }
}

static size_t logical_length(const volatile wchar_t *text, size_t units)
{
    for (size_t i = 0; i < units; ++i)
        if (!text[i])
            return i;
    return SIZE_MAX;
}

static int member(wchar_t value, const volatile wchar_t *set, size_t length)
{
    for (size_t i = 0; i < length; ++i)
        if (set[i] == value)
            return 1;
    return 0;
}

static size_t initial_span(const volatile wchar_t *text, size_t length,
                           const volatile wchar_t *set, size_t members, int accepted)
{
    size_t index = 0;
    while (index < length && member(text[index], set, members) == accepted)
        ++index;
    return index;
}

static size_t substring(const volatile wchar_t *text, size_t length,
                        const volatile wchar_t *needle, size_t needle_length)
{
    if (needle_length > length)
        return SIZE_MAX;
    for (size_t start = 0; start <= length - needle_length; ++start) {
        size_t index = 0;
        while (index < needle_length && text[start + index] == needle[index])
            ++index;
        if (index == needle_length)
            return start;
    }
    return SIZE_MAX;
}

static uint64_t digest(uint64_t initial, const wchar_t *words, size_t units)
{
    for (size_t i = 0; i < units; ++i)
        initial = initial * 257 + (uint32_t)words[i];
    return initial * 257 + units;
}

static int observe(enum operation operation, struct stimulus input, const struct guard guards[2],
                   struct observed *output)
{
    unsigned mode = (unsigned)((input.mode & ((UINT64_C(1) << 62) - 1)) % scenarios[operation]);
    struct problem problem;
    if (operation == FIND)
        substring_problem(&problem, mode, input.value);
    else
        membership_problem(&problem, mode, input.value);
    if (problem.text_units > CAPACITY || problem.pattern_units > CAPACITY)
        return 92;
    size_t text_length = logical_length(problem.text, problem.text_units);
    size_t pattern_length = logical_length(problem.pattern, problem.pattern_units);
    if (text_length == SIZE_MAX || pattern_length == SIZE_MAX)
        return 92;
    size_t index = operation == FIND ?
        substring(problem.text, text_length, problem.pattern, pattern_length) :
        initial_span(problem.text, text_length, problem.pattern, pattern_length, operation == SPAN);

    struct array a = place(&guards[0], problem.text_units, (input.mode >> 62) & 1);
    struct array b = place(&guards[1], problem.pattern_units, input.mode >> 63);
    assign_words(a.start, problem.text, problem.text_units);
    assign_words(b.start, problem.pattern, problem.pattern_units);
    wchar_t *wanted = NULL;
    if (operation == FIND ? index != SIZE_MAX : index < text_length)
        wanted = a.start + index;
    int sentinel = 700 + (int)((input.value >> 32) & 4095);
    errno = sentinel;
    size_t count = 0;
    wchar_t *actual = NULL;
    switch (operation) {
    case SPAN: count = wcsspn(a.start, b.start); break;
    case CSPAN: count = wcscspn(a.start, b.start); break;
    case BREAK: actual = wcspbrk(a.start, b.start); break;
    default: actual = wcsstr(a.start, b.start); break;
    }
    int error = errno;
    int numeric = operation == SPAN || operation == CSPAN;
    if (numeric ? count != index : actual != wanted)
        return 21;
    if (error != sentinel)
        return 22;
    if (!same_wide(a.start, problem.text, problem.text_units) ||
        !same_wide(b.start, problem.pattern, problem.pattern_units) ||
        *a.neighbor != CANARY || *b.neighbor != CANARY)
        return 23;
    int64_t normalized = (int64_t)count;
    if (!numeric)
        normalized = actual ? actual - a.start : -1;
    uint64_t contents = digest(1, a.start, problem.text_units);
    contents = digest(contents, b.start, problem.pattern_units);
    *output = (struct observed){normalized, mode, problem.text_units, problem.pattern_units,
                               text_length, pattern_length, contents, (uint64_t)error};
    return 0;
}

static int read_row(struct stimulus *input)
{
    size_t done = 0;
    while (done < sizeof *input) {
        long n = raw_read(STDIN_FILENO, (char *)input + done, sizeof *input - done);
        if (n == -EINTR)
            continue;
        if (n < 0 || (!n && done))
            return -1;
        if (!n)
            return 0;
        done += (size_t)n;
    }
    return 1;
}

static int write_row(const struct observed *output)
{
    size_t done = 0;
    while (done < sizeof *output) {
        long n = raw_write(STDOUT_FILENO, (const char *)output + done, sizeof *output - done);
        if (n == -EINTR)
            continue;
        if (n <= 0)
            return 0;
        done += (size_t)n;
    }
    return 1;
}

static int directed(enum operation operation, const struct guard guards[2])
{
    static const uint64_t seeds[] = {
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 31, 63, 127,
        UINT64_C(0x8000000000000001), UINT64_C(0x800000000000007f),
    };
    for (unsigned mode = 0; mode < scenarios[operation]; ++mode) {
        for (uint64_t sides = 0; sides < 4; ++sides) {
            for (size_t i = 0; i < sizeof seeds / sizeof *seeds; ++i) {
                struct stimulus input = {mode | (sides << 62), seeds[i]};
                struct observed output;
                int result = observe(operation, input, guards, &output);
                if (result)
                    return result;
            }
        }
    }
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2 && (argc != 3 || !same_text(argv[2], "guard")))
        return 90;
    enum operation operation = operation_from(argv[1]);
    if (operation == OPERATIONS)
        return 90;
    size_t page = linux_page_size();
    struct guard guards[2];
    if (page <= CAPACITY * sizeof(wchar_t) || page > SIZE_MAX / 3 ||
        page % _Alignof(wchar_t) || !map_guard(&guards[0], page))
        return 91;
    if (!map_guard(&guards[1], page)) {
        (void)unmap_guard(&guards[0]);
        return 91;
    }
    int result = 0;
    if (argc == 3) {
        result = directed(operation, guards);
    } else {
        struct stimulus input;
        int got = 0;
        while (!result && (got = read_row(&input)) > 0) {
            struct observed output;
            result = observe(operation, input, guards, &output);
            if (!result && !write_row(&output))
                result = 93;
        }
        if (!result && got < 0)
            result = 93;
    }
    int cleaned_first = unmap_guard(&guards[0]);
    return unmap_guard(&guards[1]) && cleaned_first ? result : 94;
}
