#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

extern long __real___al_syscall(long, long, long, long, long, long, long);

enum {
    SYS_MMAP = 9, SYS_MUNMAP = 11, SYS_MREMAP = 25,
    PAGE = 4096, FIXED_NOREPLACE = 0x100000, MAYMOVE = 1,
    INITIAL = 1, GROW, RELEASE,
    REAL = 0, FALLBACK, DOUBLE_FAILURE,
};

struct mapping { uintptr_t base; size_t length; };
static struct mapping candidates[8], old_map, new_map;
static uintptr_t old_address;
static size_t new_size;
static unsigned candidate_count, remaps, maps, unmaps, old_unmaps, expected_release;
static int phase, policy, correct_request;
static long remap_result;

static size_t rounded(size_t size)
{
    return (size + PAGE - 1) & ~(size_t)(PAGE - 1);
}

long __wrap___al_syscall(long nr, long a1, long a2, long a3, long a4, long a5, long a6)
{
    if (phase == GROW && nr == SYS_MREMAP) {
        ++remaps;
        correct_request = (uintptr_t)a1 == old_map.base && (size_t)a2 == old_map.length &&
                          (size_t)a3 == old_address - old_map.base + new_size && a4 == MAYMOVE && !a5 && !a6;
        if (!correct_request)
            return -EINVAL;
        remap_result = policy == REAL ? __real___al_syscall(nr, a1, a2, a3, a4, a5, a6) : -ENOSYS;
        if (remap_result >= 0)
            new_map = (struct mapping){(uintptr_t)remap_result, (size_t)a3};
        return remap_result;
    }
    if (phase == GROW && nr == SYS_MMAP && (size_t)a2 >= new_size) {
        ++maps;
        if (policy == DOUBLE_FAILURE)
            return -ENOMEM;
        long result = __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
        if (result >= 0)
            new_map = (struct mapping){(uintptr_t)result, (size_t)a2};
        return result;
    }
    long result = __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
    if (phase == INITIAL && nr == SYS_MMAP && result >= 0 && candidate_count < 8)
        candidates[candidate_count++] = (struct mapping){(uintptr_t)result, (size_t)a2};
    if (phase == GROW && nr == SYS_MUNMAP) {
        ++unmaps;
        old_unmaps += (uintptr_t)a1 == old_map.base && (size_t)a2 == old_map.length && !result;
    }
    if (phase == RELEASE && nr == SYS_MUNMAP && (uintptr_t)a1 == new_map.base &&
        rounded((size_t)a2) == rounded(new_map.length) && !result)
        ++expected_release;
    return result;
}

static unsigned char pattern(size_t index)
{
    return (unsigned char)((index * 193u) ^ (index >> 8) ^ 0x5bu);
}

static void fill(unsigned char *bytes, size_t size)
{
    for (size_t i = 0; i < size; ++i)
        bytes[i] = pattern(i);
}

static int unchanged(const unsigned char *bytes, size_t size)
{
    for (size_t i = 0; i < size; ++i)
        if (bytes[i] != pattern(i))
            return 0;
    return 1;
}

static unsigned char *allocate(size_t size, int over_aligned)
{
    phase = INITIAL;
    unsigned char *bytes = over_aligned ? aligned_alloc(PAGE, size) : malloc(size);
    phase = 0;
    if (!bytes || (over_aligned && (uintptr_t)bytes % PAGE))
        return NULL;
    old_address = (uintptr_t)bytes;
    for (unsigned i = 0; i < candidate_count; ++i) {
        struct mapping candidate = candidates[i];
        if (candidate.base <= old_address && old_address - candidate.base <= candidate.length &&
            size <= candidate.length - (old_address - candidate.base))
            old_map = candidate;
    }
    if (!old_map.base)
        return NULL;
    fill(bytes, size);
    return bytes;
}

static int direct(int over_aligned, int force_move, int inject)
{
    const size_t size = 1024 * 1024 + 37;
    new_size = size + 256 * 1024 + 73;
    unsigned char *old = allocate(size, over_aligned);
    if (!old)
        return 90;
    uintptr_t barrier = 0;
    if (force_move) {
        uintptr_t address = old_map.base + rounded(old_map.length);
        long result = __real___al_syscall(SYS_MMAP, (long)address, PAGE, PROT_NONE,
                                         MAP_PRIVATE | MAP_ANONYMOUS | FIXED_NOREPLACE, -1, 0);
        if (result == (long)address)
            barrier = address;
        else if (result != -EEXIST)
            return 91;
    }

    policy = inject;
    phase = GROW;
    errno = EDOM;
    unsigned char *result = realloc(old, new_size);
    phase = 0;
    int saved = errno;
    if (barrier && __real___al_syscall(SYS_MUNMAP, (long)barrier, PAGE, 0, 0, 0, 0))
        return 92;
    if (inject == DOUBLE_FAILURE) {
        if (result || saved != ENOMEM || remaps != 1 || !correct_request || maps != 1 ||
            unmaps || !unchanged(old, size))
            return 14;
        new_map = old_map;
        result = old;
    } else {
        if (!result || saved != EDOM || (uintptr_t)result % 16 || !unchanged(result, size))
            return 11;
        if (remaps != 1 || !correct_request || !new_map.base)
            return 12;
        if (inject == FALLBACK) {
            if (remap_result != -ENOSYS || maps != 1 || old_unmaps != 1 || (uintptr_t)result == old_address)
                return 13;
        } else if (remap_result < 0 || maps || unmaps ||
                   (uintptr_t)result != new_map.base + old_address - old_map.base ||
                   (force_move && (uintptr_t)result == old_address)) {
            return 15;
        }
        result[new_size - 1] = 0xa5;
        phase = GROW;
        unsigned char *smaller = realloc(result, size / 2);
        phase = 0;
        if (!smaller || !unchanged(smaller, size / 2) || remaps != 1 || errno != EDOM)
            return 16;
        result = smaller;
    }
    phase = RELEASE;
    errno = EDOM;
    free(result);
    phase = 0;
    return expected_release == 1 && errno == EDOM ? 0 : 17;
}

static int in_capacity(void)
{
    const size_t size = 1024 * 1024 + 37;
    unsigned char *bytes = allocate(size, 0);
    if (!bytes)
        return 90;
    phase = GROW;
    errno = EDOM;
    bytes = realloc(bytes, size - 128);
    if (!bytes || !unchanged(bytes, size - 128) || remaps || errno != EDOM)
        return 21;
    bytes = realloc(bytes, size);
    phase = 0;
    if (!bytes || !unchanged(bytes, size - 128) || remaps || errno != EDOM)
        return 22;
    free(bytes);
    return 0;
}

static int slab(void)
{
    const size_t size = 63;
    unsigned char *bytes = malloc(size);
    if (!bytes)
        return 90;
    fill(bytes, size);
    phase = GROW;
    errno = EDOM;
    bytes = realloc(bytes, 129);
    phase = 0;
    if (!bytes || !unchanged(bytes, size) || remaps || errno != EDOM)
        return 23;
    free(bytes);
    return 0;
}

static int overflow(void)
{
    const size_t size = 1024 * 1024 + 37;
    unsigned char *bytes = allocate(size, 0);
    if (!bytes)
        return 90;
    const size_t invalid[] = {(size_t)PTRDIFF_MAX + 1, SIZE_MAX};
    for (size_t i = 0; i < sizeof invalid / sizeof invalid[0]; ++i) {
        phase = GROW;
        errno = EDOM;
        void *result = realloc(bytes, invalid[i]);
        phase = 0;
        if (result || errno != ENOMEM || remaps || maps || unmaps || !unchanged(bytes, size))
            return 24;
    }
    free(bytes);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    const char *mode = argv[1];
    if (!strcmp(mode, "real"))
        return direct(0, 0, REAL);
    if (!strcmp(mode, "forced-move"))
        return direct(0, 1, REAL);
    if (!strcmp(mode, "aligned"))
        return direct(1, 0, REAL);
    if (!strcmp(mode, "fallback"))
        return direct(0, 0, FALLBACK);
    if (!strcmp(mode, "failure"))
        return direct(0, 0, DOUBLE_FAILURE);
    if (!strcmp(mode, "in-capacity"))
        return in_capacity();
    if (!strcmp(mode, "slab"))
        return slab();
    if (!strcmp(mode, "overflow"))
        return overflow();
    return 90;
}
