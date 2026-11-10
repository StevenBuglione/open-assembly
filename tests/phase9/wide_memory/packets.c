#include "fixture.h"

#include <sys/mman.h>

#ifndef OA_PHASE6_HOST
struct aux_entry { unsigned long type, value; };
extern const struct aux_entry *const __al_auxv;
#endif

struct stimulus { uint64_t mode, value; };
struct observed {
    int64_t result;
    uint64_t scenario, count, from, to, value, contents, error;
};
_Static_assert(sizeof(struct stimulus) == 16 && sizeof(struct observed) == 64,
               "Linux LP64 packet widths");

enum { CAPACITY = 160, CANARY = 0x31415926, UNWRITTEN = 0x52f19e34 };
static const unsigned scenarios[OPERATIONS] = {10, 8, 10, 9};

struct problem {
    wchar_t a[CAPACITY], b[CAPACITY], value;
    size_t a_units, b_units, count, from, to;
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

static wchar_t random_element(uint64_t *state)
{
    static const wchar_t values[] = {WCHAR_MIN, WCHAR_MAX, -1, 0, 1, 0x100, 0x10000, 0x1000000};
    uint32_t word = random_word(state);
    unsigned index = word & 15;
    return index < sizeof values / sizeof *values ? values[index] : element(word);
}

static void fill_words(wchar_t *words, size_t units, uint64_t *state)
{
    for (size_t i = 0; i < units; ++i)
        words[i] = random_element(state);
}

static void comparison_problem(struct problem *problem, unsigned mode, uint64_t seed)
{
    if (!mode)
        return;
    size_t n = 1 + (size_t)(seed & 127);
    if (mode == 2 || mode == 3 || mode == 7)
        n = 1;
    if ((mode == 6 || mode == 9) && n < 2)
        n = 2;
    problem->count = n;
    problem->a_units = problem->b_units = n + (mode == 8);
    uint64_t state = seed;
    fill_words(problem->a, problem->a_units, &state);
    for (size_t i = 0; i < problem->b_units; ++i)
        problem->b[i] = problem->a[i];
    switch (mode) {
    case 2:
        problem->a[0] = WCHAR_MIN;
        problem->b[0] = WCHAR_MAX;
        break;
    case 3:
        problem->a[0] = WCHAR_MAX;
        problem->b[0] = WCHAR_MIN;
        break;
    case 4:
    case 6:
        problem->a[n - 1] = -1;
        problem->b[n - 1] = 1;
        if (mode == 6)
            problem->a[0] = problem->b[0] = 0;
        break;
    case 5:
        problem->a[n - 1] = 1;
        problem->b[n - 1] = -1;
        break;
    case 7:
        problem->a[0] = element(UINT32_C(0x8000005a));
        problem->b[0] = element(UINT32_C(0x8001005a));
        break;
    case 8:
        problem->a[n] = WCHAR_MIN;
        problem->b[n] = WCHAR_MAX;
        break;
    case 9:
        problem->a[0] = -1;
        problem->b[0] = 1;
        problem->a[n - 1] = WCHAR_MAX;
        problem->b[n - 1] = WCHAR_MIN;
        break;
    }
}

static void copy_problem(struct problem *problem, unsigned mode, uint64_t seed)
{
    static const wchar_t whole[] = {WCHAR_MIN, 0x100, 0, 0x10000, -1, WCHAR_MAX, 0x1000000};
    if (!mode)
        return;
    size_t n = 1 + (size_t)(seed & 127);
    if (mode == 1)
        n = 1;
    else if (mode == 5)
        n = sizeof whole / sizeof *whole;
    else if (mode == 7)
        n = 2;
    else if (mode == 3)
        n = 1U << (seed % 8);
    problem->count = n;
    problem->a_units = n + (mode == 6);
    problem->b_units = n + (mode == 6 ? 2 : 0);
    uint64_t state = seed;
    fill_words(problem->a, problem->a_units, &state);
    for (size_t i = 0; i < problem->b_units; ++i)
        problem->b[i] = UNWRITTEN;
    if (mode == 1)
        problem->a[0] = WCHAR_MIN;
    else if (mode == 4)
        problem->a[n / 2] = 0;
    else if (mode == 5)
        for (size_t i = 0; i < n; ++i)
            problem->a[i] = whole[i];
    else if (mode == 7) {
        problem->a[0] = 1;
        problem->a[1] = -1;
    }
}

static void move_problem(struct problem *problem, unsigned mode, uint64_t seed)
{
    if (!mode)
        return;
    size_t n = 1 + (size_t)(seed & 63);
    if (mode == 1 || mode == 2)
        n = 2;
    else if (mode != 5 && mode != 6 && mode != 7 && n < 2)
        n = 2;
    problem->count = n;
    switch (mode) {
    case 1:
        problem->to = 1;
        break;
    case 2:
        problem->from = 1;
        break;
    case 3:
        problem->to = n / 2;
        break;
    case 4:
        problem->from = n / 2;
        break;
    case 6:
        problem->to = n + 1;
        break;
    case 7:
        problem->from = n + 1;
        break;
    case 8:
        problem->from = 1;
        problem->to = 2;
        break;
    case 9:
        problem->from = 2;
        problem->to = 1;
        break;
    }
    size_t last = problem->from > problem->to ? problem->from : problem->to;
    problem->a_units = last + n + (mode >= 8);
    uint64_t state = seed;
    fill_words(problem->a, problem->a_units, &state);
    if (mode == 1 || mode == 2) {
        problem->a[0] = 1;
        problem->a[1] = -1;
        problem->a[2] = WCHAR_MIN;
    }
}

static void set_problem(struct problem *problem, unsigned mode, uint64_t seed)
{
    if (!mode)
        return;
    size_t n = mode <= 3 ? 1 : 1 + (size_t)(seed & 127);
    if (mode == 8)
        n = 1U << (seed % 8);
    problem->count = n;
    problem->b_units = n + (mode == 7 ? 2 : 0);
    uint64_t state = seed;
    fill_words(problem->b, problem->b_units, &state);
    problem->value = random_element(&state);
    switch (mode) {
    case 1: problem->value = -1; break;
    case 2: problem->value = WCHAR_MIN; break;
    case 3: problem->value = 0x1000000; break;
    case 5: problem->value = 0; break;
    case 6: problem->value = WCHAR_MAX; break;
    case 8: problem->value = 0x10001; break;
    }
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
    problem.value = 0;
    problem.a_units = problem.b_units = 0;
    problem.count = problem.from = problem.to = 0;
    switch (operation) {
    case CMP: comparison_problem(&problem, mode, input.value); break;
    case COPY: copy_problem(&problem, mode, input.value); break;
    case MOVE: move_problem(&problem, mode, input.value); break;
    default: set_problem(&problem, mode, input.value); break;
    }
    struct array a = place(&guards[0], problem.a_units, (input.mode >> 62) & 1);
    struct array b = place(&guards[1], problem.b_units, input.mode >> 63);
    wchar_t expected_a[CAPACITY], expected_b[CAPACITY];
    for (size_t i = 0; i < problem.a_units; ++i)
        a.start[i] = expected_a[i] = problem.a[i];
    for (size_t i = 0; i < problem.b_units; ++i)
        b.start[i] = expected_b[i] = problem.b[i];
    int order = 0;
    for (size_t i = 0; i < problem.count; ++i) {
        switch (operation) {
        case CMP:
            if (!order)
                order = (problem.a[i] > problem.b[i]) - (problem.a[i] < problem.b[i]);
            break;
        case COPY:
            expected_b[i] = problem.a[i];
            break;
        case MOVE:
            expected_a[problem.to + i] = problem.a[problem.from + i];
            break;
        default:
            expected_b[i] = problem.value;
            break;
        }
    }
    wchar_t *from = a.start;
    wchar_t *to = b.start;
    if (operation == MOVE && problem.count) {
        from += problem.from;
        to = a.start + problem.to;
    }
    int sentinel = 700 + (int)((input.value >> 32) & 4095);
    errno = sentinel;
    wchar_t *actual = to;
    int comparison = 0;
    switch (operation) {
    case CMP:
        comparison = wmemcmp(a.start, b.start, problem.count);
        break;
    case COPY:
        actual = wmemcpy(to, from, problem.count);
        break;
    case MOVE:
        actual = wmemmove(to, from, problem.count);
        break;
    default:
        actual = wmemset(to, problem.value, problem.count);
        break;
    }
    int error = errno;
    if (operation == CMP ? (comparison > 0) - (comparison < 0) != order : actual != to)
        return 21;
    if (error != sentinel)
        return 22;
    if (!same_wide(a.start, expected_a, problem.a_units) ||
        !same_wide(b.start, expected_b, problem.b_units) ||
        (a.neighbor && *a.neighbor != CANARY) || (b.neighbor && *b.neighbor != CANARY))
        return 23;
    uint64_t contents = digest(1, a.start, problem.a_units);
    contents = digest(contents, b.start, problem.b_units);
    int64_t normalized = 0;
    if (operation == CMP)
        normalized = order;
    else if (operation == MOVE && problem.count)
        normalized = actual - a.start;
    *output = (struct observed){
        normalized,
        mode, problem.count, problem.from, problem.to, (uint32_t)problem.value,
        contents, (uint64_t)error,
    };
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
