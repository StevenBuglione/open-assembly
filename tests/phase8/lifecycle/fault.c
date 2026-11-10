#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

#include "mapping_observer.h"

extern long __real___al_syscall(long, long, long, long, long, long, long);

enum { SYS_MMAP = 9, SYS_MPROTECT = 10, SYS_MUNMAP = 11, SYS_MINCORE = 27,
       SYS_NANOSLEEP = 35, SYS_FUTEX = 202, FUTEX_WAIT = 0,
       FIRST_MAP = 1, SECOND_MAP = 2, STACK_PROTECTION = 3, JOIN_WAIT = 4 };

struct mapping { long address, length; int released; };

static struct mapping observed[2];
static int injection, attempts, count, injected, unexpected;
static int token;
static int join_ready, join_release, join_attempts;
static uintptr_t join_tid;

long __wrap___al_syscall(long nr, long a, long b, long c, long d, long e, long f)
{
    int mode = __atomic_load_n(&injection, __ATOMIC_ACQUIRE);
    if (mode == JOIN_WAIT && nr == SYS_FUTEX && a == (long)join_tid && b == FUTEX_WAIT && c > 0) {
        ++join_attempts;
        if (join_attempts == 1)
            return -EINTR;
        if (join_attempts == 2)
            return -EAGAIN;
        __atomic_store_n(&join_release, 1, __ATOMIC_RELEASE);
    }
    if (mode >= FIRST_MAP && mode <= STACK_PROTECTION && nr == SYS_MMAP && ++attempts == mode) {
        ++injected;
        return -ENOMEM;
    }
    if (mode == STACK_PROTECTION && nr == SYS_MPROTECT && b > 0) {
        for (int i = 0; i < count; ++i) {
            if (observed[i].length > 1024 * 1024 && a >= observed[i].address &&
                b <= observed[i].length && a - observed[i].address <= observed[i].length - b) {
                ++injected;
                return -EACCES;
            }
        }
    }
    long result = __real___al_syscall(nr, a, b, c, d, e, f);
    if (!mode || mode == JOIN_WAIT)
        return result;
    if (nr == SYS_MMAP && result >= 0) {
        if (count == 2)
            unexpected = 1;
        else
            observed[count++] = (struct mapping){result, b, 0};
    }
    if (nr == SYS_MUNMAP && result == 0) {
        int matched = 0;
        for (int i = 0; i < count; ++i) {
            if (a >= observed[i].address && a - observed[i].address < observed[i].length) {
                ++observed[i].released;
                matched = 1;
            }
        }
        if (!matched)
            unexpected = 1;
    }
    return result;
}

static void *return_argument(void *argument)
{
    return argument;
}

static void raw_pause(void)
{
    const struct timespec interval = {.tv_nsec = 1000000};
    (void)__real___al_syscall(SYS_NANOSLEEP, (long)&interval, 0, 0, 0, 0, 0);
}

static void *await_join(void *argument)
{
    uintptr_t tcb;
    __asm__ volatile("movq %%fs:0, %0" : "=r"(tcb));
    join_tid = tcb + 0x70;
    __atomic_store_n(&join_ready, 1, __ATOMIC_RELEASE);
    for (unsigned i = 0; i < 2000; ++i) {
        if (__atomic_load_n(&join_release, __ATOMIC_ACQUIRE))
            return argument;
        raw_pause();
    }
    return NULL;
}

static int interrupted_join(void)
{
    pthread_t handle;
    if (pthread_create(&handle, NULL, await_join, &token))
        return 85;
    for (unsigned i = 0; i < 2000 && !__atomic_load_n(&join_ready, __ATOMIC_ACQUIRE); ++i)
        raw_pause();
    if (!__atomic_load_n(&join_ready, __ATOMIC_ACQUIRE))
        return 86;
    __atomic_store_n(&injection, JOIN_WAIT, __ATOMIC_RELEASE);
    errno = EDOM;
    void *result = NULL;
    int status = pthread_join(handle, &result);
    __atomic_store_n(&injection, 0, __ATOMIC_RELEASE);
    if (status || errno != EDOM)
        return 87;
    return result == &token && join_attempts >= 3 ? 0 : 88;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (strcmp(argv[1], "interrupted-join") == 0)
        return interrupted_join();
    int mode;
    if (strcmp(argv[1], "first-map") == 0)
        mode = FIRST_MAP;
    else if (strcmp(argv[1], "second-map") == 0)
        mode = SECOND_MAP;
    else if (strcmp(argv[1], "protect") == 0)
        mode = STACK_PROTECTION;
    else
        return 91;
    __atomic_store_n(&injection, mode, __ATOMIC_RELEASE);
    pthread_t sentinel = (pthread_t)(uintptr_t)0x12345678;
    pthread_t handle = sentinel;
    errno = EDOM;
    int result = pthread_create(&handle, NULL, return_argument, &token);
    __atomic_store_n(&injection, 0, __ATOMIC_RELEASE);
    if (result != EAGAIN || memcmp(&handle, &sentinel, sizeof handle) || errno != EDOM)
        return 81;
    if (injected != 1 || unexpected ||
        (mode == STACK_PROTECTION ? (count < 1 || count != attempts) : count != mode - 1))
        return 82;
    unsigned long page = startup_page_size();
    if (!page)
        return 83;
    for (int i = 0; i < count; ++i) {
        if (!observed[i].released)
            return 83;
        for (unsigned long offset = 0; offset < (unsigned long)observed[i].length; offset += page) {
            unsigned char vector;
            long address = observed[i].address + (long)offset;
            if (__real___al_syscall(SYS_MINCORE, address, 1, (long)&vector, 0, 0, 0) != -ENOMEM)
                return 83;
        }
    }
    void *value = NULL;
    if (pthread_create(&handle, NULL, return_argument, &token) || pthread_join(handle, &value) ||
        value != &token || errno != EDOM)
        return 84;
    return 0;
}
