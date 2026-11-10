#ifdef OA_PHASE6_HOST
#define _POSIX_C_SOURCE 200809L
#endif
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

enum { ALLOCATE, ZEROED, RELEASE, RESIZE, ALIGNED, POSIX_ALIGNED };
struct packet { uint64_t flags, size, factor, seed; };
struct result {
    uint64_t success, error, layout, count, initial, first, second, retained;
};
_Static_assert(sizeof(struct packet) == 32 && sizeof(struct result) == 64, "LP64 packet widths");

static size_t extent(const struct packet *packet)
{
    static const size_t boundaries[] = {1, 15, 16, 17, 31, 32, 33, 47, 48, 49, 63, 64, 65,
                                        95, 96, 97, 127, 128, 129, 1024, 4064, 4065, 4095,
                                        4096, 4097, 8193};
    if (packet->flags & 16)
        return 1 + packet->size % 8193;
    return boundaries[packet->size % (sizeof boundaries / sizeof *boundaries)];
}

static void fill(volatile unsigned char *bytes, size_t size, uint64_t seed)
{
    for (size_t i = 0; i < size; ++i)
        bytes[i] = (unsigned char)(seed + i * 29 + (i >> 4));
}

static uint64_t digest(const volatile unsigned char *bytes, size_t size)
{
    uint64_t value = UINT64_C(0xcbf29ce484222325);
    for (size_t i = 0; i < size; ++i)
        value = (value ^ bytes[i]) * UINT64_C(0x100000001b3);
    return value;
}

static uint64_t layout(const void *first, size_t n, const void *second, size_t m)
{
    uint64_t flags = first && (uintptr_t)first % 16 == 0 ? 1 : 0;
    if (second && (uintptr_t)second % 16 == 0)
        flags |= 2;
    uintptr_t a = (uintptr_t)first, b = (uintptr_t)second;
    if (first && second && (a < b ? b - a >= n : a - b >= m))
        flags |= 4;
    return flags;
}

static uint64_t allocation_errno(const void *result)
{
    if (!result)
        return (uint64_t)errno;
#ifndef OA_PHASE6_HOST
    if (errno != EDOM)
        return UINT64_C(0x8000000000000000) | (uint64_t)errno;
#endif
    return 0;
}

static void resize(const struct packet *packet, struct result *result)
{
    size_t before = extent(packet);
    unsigned char *left = malloc(before), *right = malloc(before + 1);
    result->initial = before;
    result->layout = layout(left, before, right, before + 1);
    if (result->layout != 7)
        return;
    fill(left, before, packet->seed);
    fill(right, before + 1, packet->seed ^ 0x71);
    size_t after = (packet->flags & 32) ? 1 + packet->factor % before : before + 1 + before / 2;
    int overflow = (packet->flags & 15) == 0;
    if (overflow)
        after = SIZE_MAX - (packet->size & 4095);
    result->count = after;
    errno = EDOM;
    volatile size_t requested = after;
    unsigned char *updated = realloc(left, requested);
    result->success = updated != NULL;
    result->error = allocation_errno(updated);
    if (!updated) {
        result->retained = digest(left, before);
        result->second = digest(right, before + 1);
        free(left);
        free(right);
        return;
    }
    if (overflow || (result->layout = layout(updated, after, right, before + 1)) != 7)
        return;
    result->retained = digest(updated, after < before ? after : before);
    fill(updated, after, packet->seed ^ 0xb7);
    result->first = digest(updated, after);
    result->second = digest(right, before + 1);
    free(updated);
    free(right);
}

static void aligned(unsigned operation, const struct packet *packet, struct result *result)
{
    size_t alignment = (size_t)16 << ((packet->factor >> 2) & 7);
    size_t count = operation == ALIGNED ? alignment * (1 + packet->size % 16) : extent(packet);
    unsigned mode = (unsigned)(packet->flags & 15);
    int too_large = mode == 0;
    if (too_large)
        count = SIZE_MAX & ~(alignment - 1);
    if (operation == POSIX_ALIGNED && mode == 2)
        alignment = 3;
    result->count = count;
    result->initial = alignment;
    errno = EDOM;
    unsigned char *first;
    if (operation == ALIGNED) {
        first = aligned_alloc(alignment, count);
        result->error = allocation_errno(first);
    } else {
        int marker;
        void *out = &marker;
        int status = posix_memalign(&out, alignment, count);
        result->error = (uint64_t)status;
        int observed_errno = errno;
#ifdef OA_PHASE6_HOST
        if (too_large && status == ENOMEM && observed_errno == ENOMEM)
            observed_errno = EDOM;
#endif
        if (observed_errno != EDOM)
            result->error |= UINT64_C(0x8000000000000000) | (uint64_t)observed_errno << 32;
        result->retained = out == &marker;
        first = !status && out != &marker ? out : NULL;
    }
    result->success = first != NULL;
    if (!first || too_large || alignment == 3)
        return;
    unsigned char *second = malloc(count + 1);
    result->layout = layout(first, count, second, count + 1);
    if ((uintptr_t)first % alignment)
        result->layout &= ~UINT64_C(1);
    if (result->layout != 7)
        return;
    fill(first, count, packet->seed);
    fill(second, count + 1, packet->seed ^ 0x71);
    result->first = digest(first, count);
    result->second = digest(second, count + 1);
    free(first);
    result->retained = digest(second, count + 1);
    free(second);
}

static void observe(unsigned operation, const struct packet *packet, struct result *result)
{
    if (operation == RESIZE) {
        resize(packet, result);
        return;
    }
    if (operation == ALIGNED || operation == POSIX_ALIGNED) {
        aligned(operation, packet, result);
        return;
    }
    size_t n = extent(packet), factor = operation == ZEROED ? 1 + (packet->factor & 3) : 1;
    errno = EDOM;
    if (operation != RELEASE && (packet->flags & 15) == 0) {
        volatile size_t invalid = SIZE_MAX - (packet->size & 4095);
        void *value = operation == ZEROED ? calloc(invalid, 2) : malloc(invalid);
        result->success = value != NULL;
        result->error = allocation_errno(value);
        return;
    }
    unsigned char *left = operation == ZEROED ? calloc(n, factor) : malloc(n);
    result->success = left != NULL;
    result->error = allocation_errno(left);
    size_t count = n * factor;
    result->count = count;
    unsigned char *right = malloc(count + 1);
    result->layout = layout(left, count, right, count + 1);
    if (result->layout != 7)
        return;
    if (operation == ZEROED) {
        const volatile unsigned char *bytes = left;
        for (size_t i = 0; i < count; ++i)
            result->initial |= bytes[i];
    }
    fill(left, count, packet->seed);
    fill(right, count + 1, packet->seed ^ 0x71);
    result->first = digest(left, count);
    result->second = digest(right, count + 1);
    if (operation == RELEASE) {
        errno = EDOM;
        if (packet->flags & 64)
            free(NULL);
        if (packet->flags & 32) {
            free(right);
            result->retained = digest(left, count);
            free(left);
        } else {
            free(left);
            result->retained = digest(right, count + 1);
            free(right);
        }
        result->error = (uint64_t)errno;
    } else {
        free(left);
        result->retained = digest(right, count + 1);
        free(right);
    }
}

static int transfer(void *memory, size_t size, int writing)
{
    size_t offset = 0;
    while (offset < size) {
        unsigned char *bytes = (unsigned char *)memory + offset;
        ssize_t count = writing ? write(STDOUT_FILENO, bytes, size - offset) :
                                  read(STDIN_FILENO, bytes, size - offset);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            return count == 0 && !offset && !writing ? 0 : -1;
        offset += (size_t)count;
    }
    return 1;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    const char *const names[] = {"malloc", "calloc", "free", "realloc", "aligned_alloc", "posix_memalign"};
    unsigned operation = 0;
    while (operation < sizeof names / sizeof *names && strcmp(argv[1], names[operation]))
        ++operation;
    if (operation == sizeof names / sizeof *names)
        return 91;
    struct packet packet;
    int received;
    while ((received = transfer(&packet, sizeof packet, 0)) == 1) {
        struct result result = {0};
        observe(operation, &packet, &result);
        if (transfer(&result, sizeof result, 1) != 1)
            return 92;
    }
    return received < 0 ? 93 : 0;
}
