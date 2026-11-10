#include "fixture.h"

#include <sys/mman.h>

#ifndef OA_PHASE6_HOST
struct aux_entry { unsigned long type, value; };
extern const struct aux_entry *const __al_auxv;
#endif

struct stimulus { uint64_t mode, value; };
struct observed {
    int64_t value;
    uint64_t scenario, units_a, units_b, count, needle, digest, error;
};
_Static_assert(sizeof(struct stimulus) == 16 && sizeof(struct observed) == 64,
               "Linux LP64 wire widths");

enum { CAPACITY = 160, PAD = 0x31415926 };
static const unsigned scenarios[OPERATIONS] = {6, 10, 10, 10};

struct problem {
    wchar_t a[CAPACITY], b[CAPACITY], needle;
    size_t units_a, units_b, count;
};

struct guard { char *base; size_t page; };

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
    long mapping = kernel_call(__NR_mmap, 0, (long)(3 * page), PROT_NONE,
                               MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mapping < 0)
        return 0;
    if (kernel_call(__NR_mprotect, mapping + (long)page, (long)page,
                    PROT_READ | PROT_WRITE, 0, 0, 0)) {
        (void)kernel_call(__NR_munmap, mapping, (long)(3 * page), 0, 0, 0, 0);
        return 0;
    }
    *guard = (struct guard){(char *)mapping, page};
    return 1;
}

static int unmap_guard(const struct guard *guard)
{
    return kernel_call(__NR_munmap, (long)guard->base, (long)(3 * guard->page),
                       0, 0, 0, 0) == 0;
}

struct array { wchar_t *start, *neighbor; };

static struct array place(const struct guard *guard, const wchar_t *source, size_t count, int right)
{
    if (!count)
        return (struct array){(wchar_t *)guard->base, NULL};
    char *inside = guard->base + guard->page;
    wchar_t *start = (wchar_t *)(inside + (right ? guard->page - count * sizeof(wchar_t) : 0));
    wchar_t *neighbor = right ? start - 1 : start + count;
    for (size_t i = 0; i < count; ++i)
        start[i] = source[i];
    *neighbor = PAD;
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
    if ((word & 15) < sizeof values / sizeof *values)
        return values[word & 15];
    return element(word | 1U);
}

static void equal_prefix(struct problem *problem, size_t length, uint64_t *state)
{
    for (size_t i = 0; i < length; ++i)
        problem->a[i] = problem->b[i] = nonzero(state);
}

static void length_problem(struct problem *problem, unsigned mode, uint64_t seed)
{
    static const size_t boundary[] = {1, 2, 3, 4, 7, 8, 15, 16, 31, 32, 63, 64, 127, 128};
    static const wchar_t whole[] = {WCHAR_MIN, 0x100, 0x10000, 0x1000000, -1, 0x10ffff, WCHAR_MAX, 0};
    size_t length = 1 + (size_t)(seed & 127);
    if (mode == 0)
        length = 0;
    else if (mode == 1)
        length = 1;
    else if (mode == 3)
        length = boundary[seed % (sizeof boundary / sizeof *boundary)];
    if (mode == 5) {
        problem->units_a = sizeof whole / sizeof *whole;
        for (size_t i = 0; i < problem->units_a; ++i)
            problem->a[i] = whole[i];
        return;
    }
    uint64_t state = seed;
    for (size_t i = 0; i < length; ++i)
        problem->a[i] = nonzero(&state);
    problem->units_a = length + 1;
    if (mode == 1)
        problem->a[0] = WCHAR_MIN;
    if (mode == 4) {
        problem->a[length + 1] = -1;
        problem->units_a += 2;
    }
}

static void comparison_problem(struct problem *problem, unsigned mode, uint64_t seed)
{
    size_t length = 1 + (size_t)(seed & 127);
    uint64_t state = seed;
    equal_prefix(problem, length, &state);
    problem->units_a = problem->units_b = length + 1;
    problem->count = SIZE_MAX;
    switch (mode) {
    case 0:
        problem->a[0] = problem->b[0] = 0;
        problem->units_a = problem->units_b = 1;
        break;
    case 1:
        break;
    case 2:
    case 3:
        problem->a[0] = mode == 2 ? WCHAR_MIN : WCHAR_MAX;
        problem->b[0] = mode == 2 ? WCHAR_MAX : WCHAR_MIN;
        break;
    case 4:
        problem->a[0] = WCHAR_MIN;
        problem->b[0] = 0;
        problem->units_b = 1;
        break;
    case 5:
        problem->a[0] = 0;
        problem->b[0] = -1;
        problem->units_a = 1;
        break;
    case 6:
        problem->a[length - 1] = 0x01000005;
        problem->b[length - 1] = 0x01010005;
        break;
    case 7:
        problem->a[length - 1] = 0;
        problem->b[length - 1] = seed >> 63 ? -1 : 1;
        problem->units_a = length;
        break;
    case 8:
        problem->a[length + 1] = WCHAR_MIN;
        problem->b[length + 1] = WCHAR_MAX;
        ++problem->units_a;
        ++problem->units_b;
        break;
    default: {
        size_t index = (size_t)((seed >> 8) % length);
        problem->b[index] = element((uint32_t)problem->a[index] ^ UINT32_C(0x80000000));
        break;
    }
    }
}

static void bounded_problem(struct problem *problem, unsigned mode, uint64_t seed)
{
    if (!mode)
        return;
    size_t length = 1 + (size_t)(seed & 127);
    uint64_t state = seed;
    equal_prefix(problem, length, &state);
    problem->units_a = problem->units_b = problem->count = length;
    switch (mode) {
    case 1:
        break;
    case 2:
        problem->a[length - 1] = seed >> 63 ? WCHAR_MAX : WCHAR_MIN;
        problem->b[length - 1] = seed >> 63 ? WCHAR_MIN : WCHAR_MAX;
        break;
    case 3:
        problem->a[length] = WCHAR_MIN;
        problem->b[length] = WCHAR_MAX;
        ++problem->units_a;
        ++problem->units_b;
        break;
    case 4:
        problem->a[length + 1] = WCHAR_MIN;
        problem->b[length + 1] = WCHAR_MAX;
        problem->units_a = problem->units_b = length + 2;
        problem->count = SIZE_MAX;
        break;
    case 5:
        problem->a[0] = -1;
        problem->a[1] = problem->b[0] = 0;
        problem->units_a = 2;
        problem->units_b = 1;
        problem->count = SIZE_MAX;
        break;
    case 6:
        problem->a[0] = 0x010000ff;
        problem->b[0] = 0x010100ff;
        problem->units_a = problem->units_b = problem->count = 1;
        break;
    case 7: {
        size_t index = (size_t)((seed >> 8) % length);
        problem->a[index] = WCHAR_MAX;
        problem->b[index] = WCHAR_MIN;
        break;
    }
    case 8:
        problem->a[length - 1] = 0;
        problem->b[length - 1] = seed >> 63 ? -1 : 1;
        problem->units_b = problem->count = length + 1;
        break;
    default:
        problem->a[0] = problem->b[0] = 0;
        problem->units_a = problem->units_b = 1;
        problem->count = SIZE_MAX;
        break;
    }
}

static void memory_problem(struct problem *problem, unsigned mode, uint64_t seed)
{
    uint64_t state = seed;
    size_t length = 1 + (size_t)(seed & 127);
    problem->needle = nonzero(&state);
    if (mode == 0)
        return;
    if (mode == 1) {
        length = 1;
        problem->needle = WCHAR_MIN;
    } else if (mode == 4 && length < 3) {
        length = 3;
    } else if (mode == 5) {
        problem->needle = 0;
    } else if (mode == 6) {
        problem->needle = element(UINT32_C(0x8000005a));
    } else if (mode == 9) {
        problem->needle = WCHAR_MAX;
    }
    problem->units_a = problem->count = length;
    for (size_t i = 0; i < length; ++i) {
        wchar_t value = nonzero(&state);
        problem->a[i] = value == problem->needle ?
            element((uint32_t)value ^ UINT32_C(0x01000000)) : value;
    }
    switch (mode) {
    case 1:
    case 3:
    case 9:
        problem->a[length - 1] = problem->needle;
        break;
    case 4:
        problem->a[0] = 0;
        problem->a[1] = problem->a[length - 1] = problem->needle;
        break;
    case 5: {
        size_t index = (size_t)((seed >> 7) % length);
        problem->a[index] = problem->a[length - 1] = 0;
        break;
    }
    case 6:
        problem->a[length - 1] = element(UINT32_C(0x8001005a));
        break;
    case 7:
        problem->a[length] = problem->needle;
        ++problem->units_a;
        break;
    case 8:
        problem->a[(seed >> 8) % length] = problem->needle;
        break;
    }
}

static int64_t reference(enum operation operation, const struct problem *problem)
{
    if (operation == LEN) {
        for (size_t i = 0; i < problem->units_a; ++i)
            if (!problem->a[i])
                return (int64_t)i;
        return INT64_MIN;
    }
    if (operation == CHR) {
        for (size_t i = 0; i < problem->count; ++i)
            if (problem->a[i] == problem->needle)
                return (int64_t)i;
        return -1;
    }
    for (size_t i = 0; i < problem->count; ++i) {
        if (i >= problem->units_a || i >= problem->units_b)
            return INT64_MIN;
        wchar_t a = problem->a[i], b = problem->b[i];
        if (a != b)
            return a < b ? -1 : 1;
        if (!a)
            return 0;
    }
    return 0;
}

static uint64_t digest(const struct problem *problem)
{
    uint64_t result = 1;
    for (size_t i = 0; i < problem->units_a; ++i)
        result = result * 257 + (uint32_t)problem->a[i];
    result = result * 257 + problem->units_a;
    for (size_t i = 0; i < problem->units_b; ++i)
        result = result * 257 + (uint32_t)problem->b[i];
    return result * 257 + problem->units_b;
}

static int observe(enum operation operation, struct stimulus input, const struct guard guards[2],
                   struct observed *output)
{
    unsigned mode = (unsigned)((input.mode & UINT64_C(0x3fffffffffffffff)) % scenarios[operation]);
    struct problem problem = {0};
    if (operation == LEN)
        length_problem(&problem, mode, input.value);
    else if (operation == CMP)
        comparison_problem(&problem, mode, input.value);
    else if (operation == NCMP)
        bounded_problem(&problem, mode, input.value);
    else
        memory_problem(&problem, mode, input.value);
    int64_t expected = reference(operation, &problem);
    if (expected == INT64_MIN)
        return 92;
    struct array a = place(&guards[0], problem.a, problem.units_a, (input.mode >> 62) & 1);
    struct array b = place(&guards[1], problem.b, problem.units_b, input.mode >> 63);
    int sentinel = 700 + (int)((input.value >> 32) & 4095);
    errno = sentinel;
    int64_t value;
    if (operation == LEN) {
        size_t length = wcslen(a.start);
        if (length != (size_t)expected)
            return 21;
        value = (int64_t)length;
    } else if (operation == CHR) {
        wchar_t *match = wmemchr(a.start, problem.needle, problem.count);
        const wchar_t *address = expected < 0 ? NULL : a.start + expected;
        if (match != address)
            return 21;
        value = match ? (int64_t)(((uintptr_t)match - (uintptr_t)a.start) / sizeof(wchar_t)) : -1;
    } else {
        value = sign_of(operation == CMP ? wcscmp(a.start, b.start) :
                        wcsncmp(a.start, b.start, problem.count));
        if (value != expected)
            return 21;
    }
    int error = errno;
    if (error != sentinel)
        return 22;
    if (!same_wide(a.start, problem.a, problem.units_a) ||
        !same_wide(b.start, problem.b, problem.units_b) ||
        (a.neighbor && *a.neighbor != PAD) || (b.neighbor && *b.neighbor != PAD))
        return 23;
    *output = (struct observed){value, mode, problem.units_a, problem.units_b, problem.count,
                                (uint32_t)problem.needle, digest(&problem), (unsigned)error};
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
