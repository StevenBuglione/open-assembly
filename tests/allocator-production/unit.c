#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static int valid(const void *pointer, size_t alignment)
{
    return pointer && (uintptr_t)pointer % alignment == 0;
}

static int disjoint(const void *left, size_t left_size, const void *right, size_t right_size)
{
    uintptr_t a = (uintptr_t)left, b = (uintptr_t)right;
    return a < b ? b - a >= left_size : a - b >= right_size;
}

static unsigned char payload(size_t index, unsigned seed)
{
    return (unsigned char)(index * 29 + seed + (index >> 4));
}

static void fill(unsigned char *pointer, size_t count, unsigned seed)
{
    for (size_t i = 0; i < count; ++i)
        pointer[i] = payload(i, seed);
}

static int matches(const unsigned char *pointer, size_t count, unsigned seed)
{
    for (size_t i = 0; i < count; ++i)
        if (pointer[i] != payload(i, seed))
            return 0;
    return 1;
}

static int zeroes(const unsigned char *pointer, size_t count)
{
    for (size_t i = 0; i < count; ++i)
        if (pointer[i] != 0)
            return 0;
    return 1;
}

static int allocate(void)
{
    errno = EDOM;
    unsigned char *p = malloc(41);
    if (!valid(p, 16) || errno != EDOM)
        return 11;
    fill(p, 41, 23);
    if (!matches(p, 41, 23))
        return 12;
    free(p);

    void *first = malloc(0), *second = malloc(0);
    if (!valid(first, 16) || !valid(second, 16) || first == second || errno != EDOM)
        return 13;
    free(first);
    free(second);

    const size_t sizes[] = {1, 15, 16, 17, 31, 32, 33, 47, 48, 49, 63, 64, 65, 95, 96, 97,
                            127, 128, 129, 255, 256, 257, 1023, 1024, 1025, 4063, 4064, 4065,
                            4095, 4096, 4097, 65537};
    for (size_t i = 0; i < sizeof sizes / sizeof *sizes; ++i) {
        size_t n = sizes[i];
        p = malloc(n);
        unsigned char *q = malloc(n + 1);
        if (!valid(p, 16) || !valid(q, 16) || !disjoint(p, n, q, n + 1) || errno != EDOM)
            return 14;
        fill(p, n, 37);
        fill(q, n + 1, 123);
        if (!matches(p, n, 37) || !matches(q, n + 1, 123))
            return 15;
        free(p);
        if (!matches(q, n + 1, 123) || errno != EDOM)
            return 16;
        free(q);
    }

    volatile size_t too_large[] = {(size_t)PTRDIFF_MAX + 1, SIZE_MAX};
    for (size_t i = 0; i < sizeof too_large / sizeof *too_large; ++i) {
        errno = EDOM;
        if (malloc(too_large[i]) || errno != ENOMEM)
            return 17;
    }
    return 0;
}

static int allocate_zeroed(void)
{
    enum { GROUP = 19, FIRST = 13, SECOND = 7, COUNT = FIRST * SECOND };
    errno = EDOM;
    unsigned char *p = calloc(FIRST, SECOND);
    if (!valid(p, 16) || errno != EDOM)
        return 11;
    if (!zeroes(p, COUNT))
        return 12;
    free(p);

    unsigned char *live[GROUP];
    for (size_t i = 0; i < GROUP; ++i) {
        live[i] = malloc(COUNT);
        if (!valid(live[i], 16))
            return 90;
        fill(live[i], COUNT, (unsigned)i + 1);
    }
    for (size_t i = 0; i < GROUP; i += 2)
        free(live[i]);
    for (size_t i = 0; i < GROUP; i += 2) {
        live[i] = calloc(SECOND, FIRST);
        if (!valid(live[i], 16) || errno != EDOM || !zeroes(live[i], COUNT))
            return 13;
    }
    for (size_t i = 1; i < GROUP; i += 2)
        if (!matches(live[i], COUNT, (unsigned)i + 1))
            return 14;
    for (size_t i = 0; i < GROUP; ++i)
        free(live[i]);

    unsigned char *large = calloc(8193, 3);
    if (!valid(large, 16) || !zeroes(large, 8193 * 3) || errno != EDOM)
        return 15;
    free(large);
    volatile size_t largest = SIZE_MAX;
    void *empty[] = {calloc(0, largest), calloc(largest, 0), calloc(0, 0)};
    if (!valid(empty[0], 16) || !valid(empty[1], 16) || !valid(empty[2], 16) ||
        empty[0] == empty[1] || empty[0] == empty[2] || empty[1] == empty[2] || errno != EDOM)
        return 16;
    for (size_t i = 0; i < sizeof empty / sizeof *empty; ++i)
        free(empty[i]);

    volatile size_t invalid[][2] = {{SIZE_MAX, 2}, {2, SIZE_MAX}, {SIZE_MAX, SIZE_MAX},
                                   {(size_t)PTRDIFF_MAX + 1, 1},
                                   {2, (size_t)PTRDIFF_MAX / 2 + 1}, {1, (size_t)PTRDIFF_MAX}};
    for (size_t i = 0; i < sizeof invalid / sizeof *invalid; ++i) {
        errno = EDOM;
        if (calloc(invalid[i][0], invalid[i][1]) || errno != ENOMEM)
            return 17;
    }
    return 0;
}

static int release(void)
{
    enum { COUNT = 87, LARGE = 65539 };
    unsigned char *left = malloc(COUNT), *right = calloc(COUNT, 1), *direct = malloc(LARGE);
    void *empty = malloc(0);
    if (!valid(left, 16) || !valid(right, 16) || !valid(direct, 16) || !valid(empty, 16) ||
        !disjoint(left, COUNT, right, COUNT) || !disjoint(direct, LARGE, right, COUNT))
        return 90;
    fill(left, COUNT, 41);
    fill(right, COUNT, 73);
    fill(direct, LARGE, 117);
    errno = EDOM;
    free(NULL);
    if (errno != EDOM || !matches(left, COUNT, 41) || !matches(right, COUNT, 73) ||
        !matches(direct, LARGE, 117))
        return 11;
    errno = E2BIG;
    free(left);
    if (errno != E2BIG || !matches(right, COUNT, 73) || !matches(direct, LARGE, 117))
        return 12;
    errno = EINVAL;
    free(direct);
    if (errno != EINVAL || !matches(right, COUNT, 73))
        return 13;
    free(empty);
    if (errno != EINVAL || !matches(right, COUNT, 73))
        return 14;
    free(right);
    return errno == EINVAL ? 0 : 15;
}

static int resize(void)
{
    errno = EDOM;
    unsigned char *p = realloc(NULL, 41);
    if (!valid(p, 16) || errno != EDOM)
        return 11;
    fill(p, 41, 23);
    unsigned char *q = realloc(p, 39);
    if (!valid(q, 16) || !matches(q, 39, 23) || errno != EDOM)
        return 12;
    p = realloc(q, 197);
    if (!valid(p, 16) || !matches(p, 39, 23) || errno != EDOM)
        return 13;
    fill(p, 197, 73);
    volatile size_t impossible = (size_t)PTRDIFF_MAX + 1;
    if (realloc(p, impossible) || errno != ENOMEM || !matches(p, 197, 73))
        return 14;
    errno = EDOM;
    q = realloc(p, 0);
    if (!valid(q, 16) || errno != EDOM)
        return 15;
    free(q);
    p = realloc(NULL, 0);
    if (!valid(p, 16) || errno != EDOM)
        return 16;
    free(p);

    enum { BEFORE = 65537, AFTER = 131075 };
    p = aligned_alloc(4096, BEFORE);
    if (!valid(p, 4096))
        return 90;
    fill(p, BEFORE, 107);
    q = realloc(p, AFTER);
    if (!valid(q, 16) || !matches(q, BEFORE, 107) || errno != EDOM)
        return 17;
    fill(q, AFTER, 157);
    if (!matches(q, AFTER, 157))
        return 18;
    p = realloc(q, 17);
    if (!valid(p, 16) || !matches(p, 17, 157) || errno != EDOM)
        return 19;
    free(p);
    return 0;
}

static int align_c(void)
{
    errno = EDOM;
    unsigned char *pointer = aligned_alloc(64, 73);
    if (!valid(pointer, 64) || errno != EDOM)
        return 11;
    fill(pointer, 73, 37);
    if (!matches(pointer, 73, 37))
        return 12;
    free(pointer);
    const size_t alignments[] = {1, 2, 4, 8, 16, 32, 128, 256, 4096, 65536};
    for (size_t i = 0; i < sizeof alignments / sizeof *alignments; ++i) {
        size_t alignment = alignments[i], effective = alignment < 16 ? 16 : alignment;
        pointer = aligned_alloc(alignment, 19);
        if (!valid(pointer, effective) || errno != EDOM)
            return 13;
        fill(pointer, 19, 41);
        if (!matches(pointer, 19, 41))
            return 14;
        free(pointer);
    }
    void *empty1 = aligned_alloc(16, 0), *empty2 = aligned_alloc(4096, 0);
    if (!valid(empty1, 16) || !valid(empty2, 4096) || empty1 == empty2 || errno != EDOM)
        return 15;
    free(empty1);
    free(empty2);
    volatile size_t invalid[] = {0, 3, 24, SIZE_MAX};
    for (size_t i = 0; i < sizeof invalid / sizeof *invalid; ++i) {
        errno = EDOM;
        if (aligned_alloc(invalid[i], 19) || errno != EINVAL)
            return 16;
    }
    volatile size_t too_large = SIZE_MAX, huge_alignment = (size_t)1 << 63;
    errno = EDOM;
    if (aligned_alloc(16, too_large) || errno != ENOMEM)
        return 17;
    errno = EDOM;
    if (aligned_alloc(huge_alignment, 17) || errno != ENOMEM)
        return 18;
    return 0;
}

static int align_posix(void)
{
    int sentinel;
    void *out = &sentinel;
    errno = EDOM;
    if (posix_memalign(&out, 64, 73) || out == &sentinel || !valid(out, 64) || errno != EDOM)
        return 11;
    fill(out, 73, 97);
    if (!matches(out, 73, 97))
        return 12;
    free(out);
    const size_t alignments[] = {8, 16, 64, 256, 4096, 65536};
    for (size_t i = 0; i < sizeof alignments / sizeof *alignments; ++i) {
        size_t alignment = alignments[i];
        out = &sentinel;
        if (posix_memalign(&out, alignment, 19) || out == &sentinel ||
            !valid(out, alignment < 16 ? 16 : alignment) || errno != EDOM)
            return 13;
        fill(out, 19, 137);
        if (!matches(out, 19, 137))
            return 14;
        free(out);
    }
    void *empty = &sentinel;
    if (posix_memalign(&empty, 4096, 0) || empty == &sentinel || !valid(empty, 4096) || errno != EDOM)
        return 15;
    free(empty);
    const size_t invalid[] = {0, 1, 2, 4, 12, 24, SIZE_MAX};
    for (size_t i = 0; i < sizeof invalid / sizeof *invalid; ++i) {
        out = &sentinel;
        if (posix_memalign(&out, invalid[i], 19) != EINVAL || out != &sentinel || errno != EDOM)
            return 16;
    }
    volatile size_t too_large = SIZE_MAX, huge_alignment = (size_t)1 << 63;
    if (posix_memalign(&out, 64, too_large) != ENOMEM || out != &sentinel || errno != EDOM)
        return 17;
    if (posix_memalign(&out, huge_alignment, 17) != ENOMEM || out != &sentinel || errno != EDOM)
        return 18;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 91;
    if (!strcmp(argv[1], "malloc")) return allocate();
    if (!strcmp(argv[1], "calloc")) return allocate_zeroed();
    if (!strcmp(argv[1], "free")) return release();
    if (!strcmp(argv[1], "realloc")) return resize();
    if (!strcmp(argv[1], "aligned_alloc")) return align_c();
    if (!strcmp(argv[1], "posix_memalign")) return align_posix();
    return 92;
}
