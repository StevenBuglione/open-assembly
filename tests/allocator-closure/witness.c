#include <asm/unistd.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

extern long __real___al_syscall(long, long, long, long, long, long, long);

enum { PAGE = 4096, SLAB = 65536, OLD_SIZE = 1024 * 1024 + 37,
       NEW_SIZE = OLD_SIZE + 256 * 1024 + 73, RESERVATION = 2 * 1024 * 1024 };
enum { IDLE, COLD, SLABS, OVERFLOW, DIRECT_ALLOC, IN_PLACE, RAW_ERROR, DIRECT_FREE };

struct mapping { uintptr_t base; size_t length; int released; };
static struct {
    unsigned mode, attempts, denied, mapped, unmapped, remaps, other_unmaps;
    unsigned bad_request;
    uintptr_t reserve, old_pointer;
    struct mapping slabs[8], old_map, new_map;
    long remap_result;
} observed;

static int success(long result)
{
    return (unsigned long)result < (unsigned long)-4095;
}

static int anonymous_rw(long prot, long flags)
{
    return (prot & (PROT_READ | PROT_WRITE)) == (PROT_READ | PROT_WRITE) &&
           (flags & (MAP_ANONYMOUS | MAP_PRIVATE)) == (MAP_ANONYMOUS | MAP_PRIVATE);
}

static size_t rounded(size_t size)
{
    return (size + PAGE - 1) & ~(size_t)(PAGE - 1);
}

static void remember_mmap(uintptr_t base, size_t length)
{
    if (observed.mode == SLABS) {
        if (length != SLAB || observed.mapped == sizeof observed.slabs / sizeof *observed.slabs) {
            ++observed.bad_request;
            return;
        }
        observed.slabs[observed.mapped++] = (struct mapping){base, length, 0};
    } else if (observed.mode == DIRECT_ALLOC) {
        ++observed.mapped;
        observed.old_map = (struct mapping){base, length, 0};
    } else if (observed.mode == RAW_ERROR) {
        ++observed.mapped;
        observed.new_map = (struct mapping){base, length, 0};
    }
}

static void remember_munmap(uintptr_t base, size_t length)
{
    if (observed.mode == SLABS) {
        for (unsigned i = 0; i < observed.mapped; ++i) {
            struct mapping *map = &observed.slabs[i];
            if (!map->released && base == map->base && length == map->length) {
                map->released = 1;
                ++observed.unmapped;
                return;
            }
        }
    } else if (observed.mode == RAW_ERROR &&
               base == observed.old_map.base && length == observed.old_map.length) {
        ++observed.unmapped;
        return;
    } else if (observed.mode == DIRECT_FREE && base == observed.new_map.base &&
               rounded(length) == rounded(observed.new_map.length)) {
        ++observed.unmapped;
        return;
    }
    ++observed.other_unmaps;
}

long __wrap___al_syscall(long nr, long a1, long a2, long a3, long a4, long a5, long a6)
{
    unsigned mode = observed.mode;
    if (mode == IDLE)
        return __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
    if (nr == __NR_mmap) {
        ++observed.attempts;
        if (mode == COLD && a2 == SLAB && anonymous_rw(a3, a4)) {
            ++observed.denied;
            return -ENOMEM;
        }
        if (mode == DIRECT_ALLOC && observed.reserve && anonymous_rw(a3, a4) &&
            a2 >= OLD_SIZE && rounded((size_t)a2) <= RESERVATION - PAGE && !observed.mapped) {
            /* Replace only the prefix of this fixture's own PROT_NONE reservation. */
            a1 = (long)observed.reserve;
            a4 |= MAP_FIXED;
        }
    }
    if (nr == __NR_mremap && (mode == IN_PLACE || mode == RAW_ERROR)) {
        ++observed.remaps;
        if ((uintptr_t)a1 != observed.old_map.base || (size_t)a2 != observed.old_map.length ||
            (size_t)a3 != observed.old_pointer - observed.old_map.base + NEW_SIZE ||
            a4 != MREMAP_MAYMOVE || a5 || a6) {
            ++observed.bad_request;
            return -EINVAL;
        }
        if (mode == RAW_ERROR) {
            observed.remap_result = -4095;
            return observed.remap_result;
        }
    }
    long result = __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
    if (nr == __NR_mmap && success(result) && anonymous_rw(a3, a4))
        remember_mmap((uintptr_t)result, (size_t)a2);
    if (nr == __NR_munmap && !result)
        remember_munmap((uintptr_t)a1, (size_t)a2);
    if (nr == __NR_mremap && mode == IN_PLACE) {
        observed.remap_result = result;
        if (success(result))
            observed.new_map = (struct mapping){(uintptr_t)result, (size_t)a3, 0};
    }
    return result;
}

static int contains(struct mapping map, const void *pointer, size_t size)
{
    uintptr_t address = (uintptr_t)pointer;
    if (!map.base || map.released || address < map.base || address - map.base > map.length)
        return 0;
    return size <= map.length - (address - map.base);
}

static unsigned char pattern(size_t i, unsigned seed)
{
    return (unsigned char)(i * 193u ^ (i >> 8) ^ seed);
}

static void fill(unsigned char *bytes, size_t size, unsigned seed)
{
    for (size_t i = 0; i < size; ++i)
        bytes[i] = pattern(i, seed);
}

static int retained(const unsigned char *bytes, size_t size, unsigned seed)
{
    for (size_t i = 0; i < size; ++i)
        if (bytes[i] != pattern(i, seed))
            return 0;
    return 1;
}

static int aligned(const void *pointer)
{
    return pointer && (uintptr_t)pointer % 16 == 0;
}

static int cold_slab(void)
{
    enum { HELD = 79, LARGE = 65539, REQUEST = 2041 };
    unsigned char *first = calloc(1, HELD);
    unsigned char *second = aligned_alloc(64, LARGE);
    if (!aligned(first) || !aligned(second))
        return 90;
    fill(first, HELD, 37);
    fill(second, LARGE, 83);

    errno = EDOM;
    observed.mode = COLD;
    void *failed = malloc(REQUEST);
    observed.mode = IDLE;
    if (failed || errno != ENOMEM)
        return 11;
    if (!observed.denied || observed.attempts != observed.denied || observed.unmapped || observed.other_unmaps)
        return 12;
    if (!retained(first, HELD, 37) || !retained(second, LARGE, 83))
        return 13;

    errno = EDOM;
    observed.mode = SLABS;
    unsigned char *retry = malloc(REQUEST);
    observed.mode = IDLE;
    if (!aligned(retry) || errno != EDOM || observed.mapped != 1 ||
        !contains(observed.slabs[0], retry, REQUEST))
        return 14;
    fill(retry, REQUEST, 131);
    if (!retained(retry, REQUEST, 131) || !retained(first, HELD, 37) || !retained(second, LARGE, 83))
        return 15;
    free(retry);
    free(second);
    free(first);
    return 0;
}

static int overflow(void)
{
    int marker;
    void *out = &marker;
    volatile size_t alignment = (size_t)1 << 63, maximum = (size_t)PTRDIFF_MAX;
    observed.mode = OVERFLOW;
    errno = EDOM;
    if (aligned_alloc(alignment, maximum) || errno != ENOMEM)
        return 11;
    errno = EDOM;
    if (posix_memalign(&out, alignment, maximum) != ENOMEM || out != &marker || errno != EDOM)
        return 12;
    observed.mode = IDLE;
    return observed.attempts || observed.unmapped || observed.other_unmaps ? 13 : 0;
}

enum { SLOT_SIZE = 4064, SLOT_LIMIT = 96, REQUIRED_SLABS = 4 };
struct allocation { unsigned char *bytes; unsigned slab, seed; };

static int record_allocation(struct allocation *live, unsigned count, unsigned sizes[REQUIRED_SLABS])
{
    errno = EDOM;
    unsigned char *bytes = malloc(SLOT_SIZE);
    if (!aligned(bytes) || errno != EDOM || observed.bad_request || observed.mapped > REQUIRED_SLABS)
        return 0;
    unsigned index = 0;
    while (index < observed.mapped && !contains(observed.slabs[index], bytes, SLOT_SIZE))
        ++index;
    if (index == observed.mapped)
        return 0;
    for (unsigned i = 0; i < count; ++i) {
        uintptr_t a = (uintptr_t)bytes, b = (uintptr_t)live[i].bytes;
        if (a < b ? b - a < SLOT_SIZE : a - b < SLOT_SIZE)
            return 0;
    }
    unsigned seed = count * 13 + 17;
    live[count] = (struct allocation){bytes, index, seed};
    ++sizes[index];
    fill(bytes, SLOT_SIZE, seed);
    return 1;
}

static int retained_live(const struct allocation *live, unsigned count)
{
    for (unsigned i = 0; i < count; ++i)
        if (live[i].bytes && (!contains(observed.slabs[live[i].slab], live[i].bytes, SLOT_SIZE) ||
                             !retained(live[i].bytes, SLOT_SIZE, live[i].seed)))
            return 0;
    return 1;
}

static int slab_lists(void)
{
    struct allocation live[SLOT_LIMIT];
    unsigned sizes[REQUIRED_SLABS] = {0}, count = 0;
    observed.mode = SLABS;
    while (observed.mapped < REQUIRED_SLABS) {
        if (count == SLOT_LIMIT || !record_allocation(live, count, sizes))
            return 21;
        ++count;
    }
    if (!sizes[0] || sizes[0] != sizes[1] || sizes[0] != sizes[2] || sizes[3] != 1)
        return 22;
    while (sizes[3] < sizes[0]) {
        if (count == SLOT_LIMIT || !record_allocation(live, count, sizes))
            return 23;
        ++count;
    }

    /* There is one reusable slot among otherwise full slabs. */
    uintptr_t hole = (uintptr_t)live[0].bytes;
    free(live[0].bytes);
    if (errno != EDOM)
        return 24;
    live[0].bytes = NULL;
    unsigned char *replacement = malloc(SLOT_SIZE);
    if ((uintptr_t)replacement != hole || observed.mapped != REQUIRED_SLABS ||
        !contains(observed.slabs[live[0].slab], replacement, SLOT_SIZE) || errno != EDOM)
        return 24;
    live[0].bytes = replacement;
    fill(replacement, SLOT_SIZE, live[0].seed);
    if (!retained_live(live, count))
        return 25;

    const unsigned order[] = {1, 3, 0, 2};
    for (unsigned group = 0; group < sizeof order / sizeof *order; ++group) {
        for (unsigned i = 0; i < count; ++i) {
            if (live[i].slab == order[group]) {
                free(live[i].bytes);
                live[i].bytes = NULL;
            }
        }
        if (!retained_live(live, count) || observed.other_unmaps || observed.unmapped < group ||
            errno != EDOM)
            return 26;
    }

    unsigned previous = observed.mapped, spare = observed.mapped - observed.unmapped;
    unsigned char *again = malloc(SLOT_SIZE);
    if (spare > 1 || !aligned(again) || observed.mapped != previous + (spare == 0))
        return 27;
    unsigned active = 0;
    while (active < observed.mapped && !contains(observed.slabs[active], again, SLOT_SIZE))
        ++active;
    if (active == observed.mapped)
        return 27;
    fill(again, SLOT_SIZE, 183);
    if (!retained(again, SLOT_SIZE, 183))
        return 27;
    free(again);
    observed.mode = IDLE;
    return observed.mapped - observed.unmapped <= 1 && !observed.other_unmaps && errno == EDOM ? 0 : 27;
}

static int direct_growth(int in_place)
{
    if (in_place) {
        long reserve = __real___al_syscall(__NR_mmap, 0, RESERVATION, PROT_NONE,
                                          MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (!success(reserve))
            return 90;
        observed.reserve = (uintptr_t)reserve;
    }
    errno = EDOM;
    observed.mode = DIRECT_ALLOC;
    unsigned char *old = malloc(OLD_SIZE);
    observed.mode = IDLE;
    if (!aligned(old) || errno != EDOM || observed.mapped != 1 ||
        !contains(observed.old_map, old, OLD_SIZE) ||
        (in_place && observed.old_map.base != observed.reserve))
        return 91;
    observed.old_pointer = (uintptr_t)old;
    fill(old, OLD_SIZE, 73);
    if (in_place) {
        size_t used = rounded(observed.old_map.length);
        if (used >= RESERVATION || NEW_SIZE > RESERVATION - PAGE ||
            __real___al_syscall(__NR_munmap, (long)(observed.reserve + used),
                                RESERVATION - used, 0, 0, 0, 0))
            return 92;
    }

    observed.mode = in_place ? IN_PLACE : RAW_ERROR;
    unsigned maps_before = observed.attempts;
    errno = EDOM;
    unsigned char *updated = realloc(old, NEW_SIZE);
    observed.mode = IDLE;
    if (!aligned(updated) || errno != EDOM)
        return 31;
    if (observed.remaps != 1 || observed.bad_request)
        return 32;
    if (in_place) {
        if (observed.remap_result != (long)observed.old_map.base ||
            (uintptr_t)updated != observed.old_pointer || observed.attempts != maps_before ||
            observed.unmapped || observed.other_unmaps)
            return 33;
    } else if (observed.remap_result != -4095 || (uintptr_t)updated == observed.old_pointer ||
               observed.mapped != 2 || observed.attempts != maps_before + 1 ||
               observed.unmapped != 1 || observed.other_unmaps) {
        return 34;
    }
    if (!contains(observed.new_map, updated, NEW_SIZE) || !retained(updated, OLD_SIZE, 73))
        return 35;
    updated[NEW_SIZE - 1] = 0xa5;
    observed.mode = DIRECT_FREE;
    free(updated);
    observed.mode = IDLE;
    return observed.unmapped == (unsigned)(in_place ? 1 : 2) &&
           !observed.other_unmaps && errno == EDOM ? 0 : 36;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 93;
    if (!strcmp(argv[1], "cold-slab")) return cold_slab();
    if (!strcmp(argv[1], "alignment-overflow")) return overflow();
    if (!strcmp(argv[1], "slab-lists")) return slab_lists();
    if (!strcmp(argv[1], "in-place-remap")) return direct_growth(1);
    if (!strcmp(argv[1], "raw-remap-error")) return direct_growth(0);
    return 94;
}
