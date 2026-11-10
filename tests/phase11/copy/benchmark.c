#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static _Alignas(64) unsigned char source[1048576 + 32];
static _Alignas(64) unsigned char destination[1048576 + 32];

static uint64_t nanoseconds(struct timespec instant)
{
    return (uint64_t)instant.tv_sec * UINT64_C(1000000000) + (uint64_t)instant.tv_nsec;
}

static unsigned sample(const unsigned char *p, size_t length)
{
    return p[0] + 3U * p[length / 2] + 5U * p[length - 1];
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    char *end;
    size_t length = strtoul(argv[1], &end, 10);
    if (*end || length < 256 || length > 1048576 || (length & (length - 1)))
        return 2;
    const size_t iterations = (128U * 1024U * 1024U) / length;
    for (size_t i = 0; i < length + 32; ++i)
        source[i] = (unsigned char)((i * 61U) ^ (i >> 7));
    uint64_t expected = 0;
    for (size_t i = 0; i < 32; ++i)
        expected += sample(source + ((i * 3) & 31), length);
    expected *= iterations / 32;
    if (memcpy(destination, source, length) != destination)
        return 3;

    struct timespec start, finish, cpu_start, cpu_finish;
    if (clock_gettime(CLOCK_THREAD_CPUTIME_ID, &cpu_start) ||
        clock_gettime(CLOCK_MONOTONIC, &start))
        return 4;
    uint64_t checksum = 0;
    for (size_t i = 0; i < iterations; ++i) {
        unsigned char *dst = destination + ((i * 5) & 31);
        const unsigned char *src = source + ((i * 3) & 31);
        if (memcpy(dst, src, length) != dst)
            return 5;
        checksum += sample(dst, length);
    }
    if (clock_gettime(CLOCK_MONOTONIC, &finish) ||
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &cpu_finish) || checksum != expected)
        return 6;
    printf("%lu %lu %lu\n", (unsigned long)(nanoseconds(finish) - nanoseconds(start)),
           (unsigned long)(nanoseconds(cpu_finish) - nanoseconds(cpu_start)), (unsigned long)checksum);
    return 0;
}
