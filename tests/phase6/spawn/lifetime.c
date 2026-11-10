#include "../kernel_abi.h"
#include <spawn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

enum { capacity = 64 };
static uintptr_t live[capacity];
static unsigned allocated, released, depth, tracking, problem;
static unsigned malloc_calls, calloc_calls, realloc_calls, free_calls;

void *__real_malloc(size_t);
void *__real_calloc(size_t, size_t);
void *__real_realloc(void *, size_t);
void __real_free(void *);

static void add(uintptr_t key)
{
    if (!key)
        return;
    unsigned free_slot = capacity;
    for (unsigned i = 0; i < capacity; ++i) {
        if (live[i] == key) {
            problem = 1;
            return;
        }
        if (!live[i] && free_slot == capacity)
            free_slot = i;
    }
    if (free_slot == capacity) {
        problem = 1;
        return;
    }
    live[free_slot] = key;
    ++allocated;
}

static void drop(uintptr_t key)
{
    if (!key)
        return;
    for (unsigned i = 0; i < capacity; ++i) {
        if (live[i] == key) {
            live[i] = 0;
            ++released;
            return;
        }
    }
    problem = 1;
}

void *__wrap_malloc(size_t size)
{
    ++depth;
    void *result = __real_malloc(size);
    if (--depth == 0 && tracking) {
        ++malloc_calls;
        add((uintptr_t)result);
    }
    return result;
}

void *__wrap_calloc(size_t count, size_t size)
{
    ++depth;
    void *result = __real_calloc(count, size);
    if (--depth == 0 && tracking) {
        ++calloc_calls;
        add((uintptr_t)result);
    }
    return result;
}

void *__wrap_realloc(void *pointer, size_t size)
{
    uintptr_t old = (uintptr_t)pointer;
    ++depth;
    void *result = __real_realloc(pointer, size);
    if (--depth == 0 && tracking) {
        ++realloc_calls;
        if (result) {
            drop(old);
            add((uintptr_t)result);
        }
    }
    return result;
}

void __wrap_free(void *pointer)
{
    if (depth == 0 && tracking) {
        ++free_calls;
        drop((uintptr_t)pointer);
    }
    ++depth;
    __real_free(pointer);
    --depth;
}

static int verify(int result, unsigned live_before, int status, int report)
{
    tracking = 0;
    unsigned live_after = 0;
    for (unsigned i = 0; i < capacity; ++i)
        live_after += live[i] != 0;
    if (result || errno != TEST_ERRNO || problem || !live_before ||
        allocated != released || live_after)
        return status;
    if (report) {
        if (printf("malloc=%u calloc=%u realloc=%u free=%u allocated=%u released=%u live_before=%u live_after=%u\n",
                   malloc_calls, calloc_calls, realloc_calls, free_calls, allocated, released,
                   live_before, live_after) < 0 || fflush(stdout))
            return status + 1;
    }
    return 0;
}

static int release_attributes(int report)
{
    posix_spawnattr_t attr;
    errno = TEST_ERRNO;
    tracking = 1;
    if (posix_spawnattr_init(&attr) || errno != TEST_ERRNO)
        return 10;
    unsigned live_before = allocated - released;
    int result = posix_spawnattr_destroy(&attr);
    return verify(result, live_before, 11, report);
}

static int release_actions(int report)
{
    posix_spawn_file_actions_t actions;
    errno = TEST_ERRNO;
    tracking = 1;
    if (posix_spawn_file_actions_init(&actions) ||
        posix_spawn_file_actions_addopen(&actions, 7, "owned-path-one", O_RDONLY, 0) ||
        posix_spawn_file_actions_addclose(&actions, 8) ||
        posix_spawn_file_actions_addopen(&actions, 9, "owned-path-two", O_RDONLY, 0) ||
        errno != TEST_ERRNO)
        return 20;
    unsigned live_before = allocated - released;
    int result = posix_spawn_file_actions_destroy(&actions);
    return verify(result, live_before, 21, report);
}

int main(int argc, char **argv)
{
    int report = argc == 3 && same_text(argv[2], "report");
    if (argc != 2 && !report)
        return 1;
    if (same_text(argv[1], "attributes")) return release_attributes(report);
    if (same_text(argv[1], "actions")) return release_actions(report);
    return 2;
}
