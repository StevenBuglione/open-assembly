#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

enum { PAGE_BYTES = 4096, BATCH_SLOTS = 512, RSS_SLOTS = 8192 };
static const size_t classes[] = {1, 15, 24, 40, 72, 120, 248, 504, 1000, 2032, 4096, 7000, 16384, 65536};
static unsigned char *slots[RSS_SLOTS];

static size_t mixed_size(size_t index)
{
    return classes[index % (sizeof classes / sizeof classes[0])];
}

static unsigned char marker(size_t tag, size_t index)
{
    return (unsigned char)((tag * 59 + index * 23) ^ (index >> 7));
}

static void touch(unsigned char *block, size_t start, size_t size, size_t tag)
{
    for (size_t i = start; i < size; i += PAGE_BYTES)
        block[i] = marker(tag, i);
    block[size - 1] = marker(tag, size - 1);
}

static int verify(const unsigned char *block, size_t size, size_t tag, uint64_t *sum)
{
    for (size_t i = 0; i < size; i += PAGE_BYTES) {
        if (block[i] != marker(tag, i))
            return 0;
        *sum += block[i];
    }
    if (block[size - 1] != marker(tag, size - 1))
        return 0;
    *sum += block[size - 1];
    return 1;
}

static int batches(int mixed, uint64_t *sum)
{
    const size_t count = mixed ? 256 : 2048;
    for (size_t batch = 0; batch < count; ++batch) {
        for (size_t slot = 0; slot < BATCH_SLOTS; ++slot) {
            const size_t tag = slot + batch * BATCH_SLOTS;
            const size_t size = mixed ? mixed_size(tag) : 32;
            slots[slot] = malloc(size);
            if (!slots[slot])
                return 0;
            touch(slots[slot], 0, size, tag);
        }
        for (size_t i = 0; i < BATCH_SLOTS; ++i) {
            const size_t slot = (i * 73) % BATCH_SLOTS;
            const size_t tag = slot + batch * BATCH_SLOTS;
            const size_t size = mixed ? mixed_size(tag) : 32;
            if (!verify(slots[slot], size, tag, sum))
                return 0;
            free(slots[slot]);
        }
    }
    return 1;
}

static int growth(uint64_t *sum)
{
    for (size_t chain = 0; chain < 16; ++chain) {
        size_t size = 64 * 1024;
        unsigned char *block = malloc(size);
        if (!block)
            return 0;
        touch(block, 0, size, chain);
        while (size < 8 * 1024 * 1024) {
            const size_t next = size * 2;
            unsigned char *replacement = realloc(block, next);
            if (!replacement || !verify(replacement, size, chain, sum))
                return 0;
            touch(replacement, size, next, chain);
            block = replacement;
            size = next;
        }
        if (!verify(block, size, chain, sum))
            return 0;
        free(block);
    }
    return 1;
}

static int sample_rss(unsigned long *rss)
{
    FILE *file = fopen("/proc/self/smaps_rollup", "r");
    if (!file)
        return 0;
    char line[256];
    int found = 0;
    while (fgets(line, sizeof line, file)) {
        if (strncmp(line, "Rss:", 4))
            continue;
        char *end;
        const unsigned long kib = strtoul(line + 4, &end, 10);
        while (*end == ' ' || *end == '\t')
            ++end;
        if (kib && !strcmp(end, "kB\n")) {
            *rss = kib;
            found = 1;
        }
        break;
    }
    return fclose(file) == 0 && found;
}

static int retained(void)
{
    unsigned long rss[4];
    if (!sample_rss(&rss[0]))
        return 7;
    for (size_t i = 0; i < RSS_SLOTS; ++i) {
        const size_t size = mixed_size(i);
        slots[i] = malloc(size);
        if (!slots[i])
            return 4;
        touch(slots[i], 0, size, i);
    }
    if (!sample_rss(&rss[1]))
        return 7;
    uint64_t sum = 0;
    for (size_t i = 0; i < RSS_SLOTS; ++i) {
        if (i % 17) {
            if (!verify(slots[i], mixed_size(i), i, &sum))
                return 5;
            free(slots[i]);
        }
    }
    if (!sample_rss(&rss[2]))
        return 7;
    for (size_t i = 0; i < RSS_SLOTS; i += 17) {
        if (!verify(slots[i], mixed_size(i), i, &sum))
            return 5;
        free(slots[i]);
    }
    if (!sample_rss(&rss[3]))
        return 7;
    printf("%lu %lu %lu %lu %lu\n", rss[0], rss[1], rss[2], rss[3], (unsigned long)sum);
    return 0;
}

static uint64_t ns(struct timespec t)
{
    return (uint64_t)t.tv_sec * UINT64_C(1000000000) + (uint64_t)t.tv_nsec;
}

static int workload(const char *name, uint64_t *sum)
{
    if (!strcmp(name, "small"))
        return batches(0, sum);
    if (!strcmp(name, "mixed"))
        return batches(1, sum);
    if (!strcmp(name, "growth"))
        return growth(sum);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2 || sysconf(_SC_PAGESIZE) != PAGE_BYTES)
        return 1;
    if (!strcmp(argv[1], "rss"))
        return retained();
    uint64_t warm = 0, measured = 0;
    if (!workload(argv[1], &warm))
        return 2;
    struct timespec wall_start, wall_end, cpu_start, cpu_end;
    if (clock_gettime(CLOCK_THREAD_CPUTIME_ID, &cpu_start) || clock_gettime(CLOCK_MONOTONIC, &wall_start))
        return 3;
    if (!workload(argv[1], &measured) || measured != warm)
        return 5;
    if (clock_gettime(CLOCK_MONOTONIC, &wall_end) || clock_gettime(CLOCK_THREAD_CPUTIME_ID, &cpu_end))
        return 3;
    printf("%lu %lu %lu\n", (unsigned long)(ns(wall_end) - ns(wall_start)),
           (unsigned long)(ns(cpu_end) - ns(cpu_start)), (unsigned long)measured);
    return 0;
}
