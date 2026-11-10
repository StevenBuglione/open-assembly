#include "fixture.h"

#include <sys/mman.h>

#ifndef OA_PHASE6_HOST
struct aux_entry { unsigned long type, value; };
extern const struct aux_entry *const __al_auxv;
#endif

struct stimulus { uint64_t mode, value; };
struct observed {
    int64_t value;
    uint64_t scenario, source_units, destination_units, count, needle, contents, error;
};
_Static_assert(sizeof(struct stimulus) == 16 && sizeof(struct observed) == 64,
               "Linux LP64 wire widths");

enum { CAPACITY = 160, CANARY = 0x31415926, UNWRITTEN = 0x52f19e34 };
static const unsigned scenarios[OPERATIONS] = {10, 10, 7, 10};

struct problem {
    wchar_t source[CAPACITY], needle;
    size_t source_units, destination_units;
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

static void fill_source(struct problem *problem, size_t units, uint64_t *state, wchar_t avoid)
{
    for (size_t i = 0; i < units; ++i) {
        wchar_t item = nonzero(state);
        if (item == avoid) {
            item = element((uint32_t)item ^ UINT32_C(0x01000000));
            if (!item)
                item = 1;
        }
        problem->source[i] = item;
    }
}

static void search_problem(struct problem *problem, unsigned mode, uint64_t seed)
{
    uint64_t state = seed;
    size_t length = 1 + (size_t)(seed & 127);
    problem->needle = nonzero(&state);
    if (mode < 2) {
        length = 0;
        if (!mode)
            problem->needle = 0;
    } else if (mode == 2) {
        length = 1;
        problem->needle = WCHAR_MIN;
    } else if (mode == 3) {
        if (length < 3)
            length = 3;
        problem->needle = seed >> 63 ? WCHAR_MIN : -1;
    } else if (mode == 4) {
        problem->needle = 0;
    } else if (mode == 5) {
        problem->needle = WCHAR_MIN;
    } else if (mode == 6) {
        problem->needle = element(UINT32_C(0x8000005a));
    }
    fill_source(problem, length, &state, problem->needle);
    problem->source_units = length + 1;
    switch (mode) {
    case 2:
    case 7:
        problem->source[length - 1] = problem->needle;
        break;
    case 3:
        problem->source[0] = problem->source[length - 1] = problem->needle;
        break;
    case 4:
        problem->source[length + 1] = -1;
        problem->source_units += 2;
        break;
    case 5:
        problem->source[length + 1] = problem->needle;
        ++problem->source_units;
        break;
    case 6:
        problem->source[length - 1] = element(UINT32_C(0x8001005a));
        break;
    case 8:
        problem->source[(seed >> 9) % length] = problem->needle;
        break;
    case 9:
        problem->source[length / 3] = problem->source[length - 1] = problem->needle;
        break;
    }
}

static void copy_problem(struct problem *problem, unsigned mode, uint64_t seed)
{
    static const size_t boundary[] = {1, 2, 3, 4, 7, 8, 15, 16, 31, 32, 63, 64, 127, 128};
    static const wchar_t whole[] = {WCHAR_MIN, 0x100, 0x10000, 0x1000000, -1, WCHAR_MAX, 0};
    uint64_t state = seed;
    size_t length = 1 + (size_t)(seed & 127);
    if (!mode)
        length = 0;
    else if (mode == 1)
        length = 1;
    else if (mode == 3)
        length = boundary[seed % (sizeof boundary / sizeof *boundary)];
    if (mode == 5) {
        problem->source_units = problem->destination_units = sizeof whole / sizeof *whole;
        for (size_t i = 0; i < problem->source_units; ++i)
            problem->source[i] = whole[i];
        return;
    }
    if (mode == 6)
        length = 2;
    fill_source(problem, length, &state, 0);
    problem->source_units = problem->destination_units = length + 1;
    if (mode == 1)
        problem->source[0] = WCHAR_MIN;
    else if (mode == 4) {
        problem->source[length + 1] = -1;
        problem->source_units += 2;
    } else if (mode == 6) {
        problem->source[0] = 1;
        problem->source[1] = -1;
    }
}

static void bounded_problem(struct problem *problem, unsigned mode, uint64_t seed)
{
    if (!mode)
        return;
    uint64_t state = seed;
    size_t count = 1 + (size_t)(seed & 127);
    if (mode == 6 && count < 3)
        count = 3;
    else if (mode == 7)
        count = 1;
    else if (mode == 9)
        count = 32 + (size_t)(seed % 97);
    problem->destination_units = problem->source_units = count;
    fill_source(problem, count, &state, 0);
    switch (mode) {
    case 1:
        break;
    case 2:
        problem->source[count] = -1;
        problem->source_units += 2;
        break;
    case 3:
        problem->source[count - 1] = 0;
        break;
    case 4: {
        size_t prefix = count / 2;
        problem->source[prefix] = 0;
        problem->source_units = prefix + 1;
        problem->destination_units += 2;
        break;
    }
    case 5:
        problem->source[0] = 0;
        problem->source_units = 1;
        break;
    case 6:
        problem->source[1] = 0;
        problem->source[2] = WCHAR_MAX;
        break;
    case 7:
        problem->source[0] = WCHAR_MIN;
        break;
    case 8:
        ++problem->source_units;
        break;
    default:
        problem->source[0] = 1;
        problem->source[1] = -1;
        problem->source[2] = 0x10000;
        problem->source[3] = WCHAR_MIN;
        problem->source[4] = 0;
        problem->source_units = 5;
        break;
    }
}

static wchar_t *search_reference(struct array source, const struct problem *problem, int last)
{
    wchar_t *found = NULL;
    for (size_t i = 0; i < problem->source_units; ++i) {
        wchar_t item = problem->source[i];
        if (item == problem->needle) {
            found = source.start + i;
            if (!last)
                break;
        }
        if (!item)
            break;
    }
    return found;
}

static int copy_reference(wchar_t expected[CAPACITY], const struct problem *problem, int bounded)
{
    int ended = 0;
    for (size_t i = 0; i < problem->destination_units; ++i) {
        if (ended) {
            expected[i] = 0;
        } else {
            if (i >= problem->source_units)
                return 0;
            expected[i] = problem->source[i];
            ended = expected[i] == 0;
        }
    }
    return bounded || ended;
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
    struct problem problem = {0};
    if (operation == FIRST || operation == LAST)
        search_problem(&problem, mode, input.value);
    else if (operation == COPY)
        copy_problem(&problem, mode, input.value);
    else
        bounded_problem(&problem, mode, input.value);

    struct array source = place(&guards[0], problem.source_units, (input.mode >> 62) & 1);
    struct array destination = place(&guards[1], problem.destination_units, input.mode >> 63);
    for (size_t i = 0; i < problem.source_units; ++i)
        source.start[i] = problem.source[i];
    for (size_t i = 0; i < problem.destination_units; ++i)
        destination.start[i] = UNWRITTEN;

    wchar_t expected[CAPACITY] = {0};
    int search = operation == FIRST || operation == LAST;
    wchar_t *wanted = destination.start;
    if (search)
        wanted = search_reference(source, &problem, operation == LAST);
    else if (!copy_reference(expected, &problem, operation == NCOPY))
        return 92;
    int sentinel = 700 + (int)((input.value >> 32) & 4095);
    errno = sentinel;
    wchar_t *actual;
    switch (operation) {
    case FIRST:
        actual = wcschr(source.start, problem.needle);
        break;
    case LAST:
        actual = wcsrchr(source.start, problem.needle);
        break;
    case COPY:
        actual = wcscpy(destination.start, source.start);
        break;
    default:
        actual = wcsncpy(destination.start, source.start, problem.destination_units);
        break;
    }
    int seen_errno = errno;
    if (actual != wanted)
        return 21;
    if (seen_errno != sentinel)
        return 22;
    if (!same_wide(source.start, problem.source, problem.source_units) ||
        !same_wide(destination.start, expected, problem.destination_units) ||
        (source.neighbor && *source.neighbor != CANARY) ||
        (destination.neighbor && *destination.neighbor != CANARY))
        return 23;
    uint64_t contents = digest(1, source.start, problem.source_units);
    contents = digest(contents, destination.start, problem.destination_units);
    *output = (struct observed){
        search ? (actual ? actual - source.start : -1) : 0,
        mode, problem.source_units, problem.destination_units,
        operation == NCOPY ? problem.destination_units : 0,
        (uint32_t)problem.needle, contents, (uint64_t)seen_errno,
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
