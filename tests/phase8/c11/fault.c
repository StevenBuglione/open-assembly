#include "support.h"

enum { SYS_MMAP = 9, SYS_MUNMAP = 11, SYS_NANOSLEEP = 35, SYS_SCHED_YIELD = 24 };
static int armed, reject_mapping, mapping_calls, unmap_seen, sleep_seen, yield_seen;
static long mapped, mapped_bytes;

extern long __real___al_syscall(long, long, long, long, long, long, long);

long __wrap___al_syscall(long nr, long a, long b, long c, long d, long e, long f)
{
    if (armed && nr == SYS_MMAP && (d & 0x22) == 0x22) { /* MAP_PRIVATE|MAP_ANONYMOUS */
        ++mapping_calls;
        if (mapping_calls == reject_mapping)
            return -ENOMEM;
        long result = __real___al_syscall(nr, a, b, c, d, e, f);
        if (result > 0) {
            mapped = result;
            mapped_bytes = b;
        }
        return result;
    }
    if (armed && nr == SYS_MUNMAP && a == mapped && b == mapped_bytes)
        ++unmap_seen;
    if (armed && nr == SYS_NANOSLEEP && a) {
        const struct timespec *request = (const void *)a;
        if (request->tv_sec == 2 && request->tv_nsec == 246 && b) {
            struct timespec *remaining = (void *)b;
            remaining->tv_sec = 1;
            remaining->tv_nsec = 135;
            ++sleep_seen;
            return -EINTR;
        }
    }
    if (armed && nr == SYS_SCHED_YIELD)
        ++yield_seen;
    return __real___al_syscall(nr, a, b, c, d, e, f);
}

static int should_not_run(void *arg)
{
    (void)arg;
    return 91;
}

static int allocation_failure(int index)
{
    thrd_t sentinel = thrd_current();
    thrd_t handle = sentinel;
    reject_mapping = index;
    armed = 1;
    errno = EDOM;
    int result = thrd_create(&handle, should_not_run, NULL);
    armed = 0;
    if (!correct(result, thrd_nomem) || !thrd_equal(handle, sentinel))
        return 11;
    if (mapping_calls != index || (index == 1 && (mapped || unmap_seen)) ||
        (index == 2 && (mapped <= 0 || mapped_bytes <= 0 || unmap_seen != 1)))
        return 12;
    return 0;
}

static int interrupted(void)
{
    struct timespec aliased = {2, 246};
    armed = 1;
    errno = EDOM;
    int result = thrd_sleep(&aliased, &aliased);
    armed = 0;
    if (!correct(result, -1) || sleep_seen != 1 || aliased.tv_sec != 1 || aliased.tv_nsec != 135)
        return 21;
    return 0;
}

static int scheduler(void)
{
    armed = 1;
    errno = EDOM;
    thrd_yield();
    armed = 0;
    return correct(0, 0) && yield_seen == 1 ? 0 : 31;
}

int main(int argc, char **argv)
{
    if (is_mode(argc, argv, "first"))
        return allocation_failure(1);
    if (is_mode(argc, argv, "second"))
        return allocation_failure(2);
    if (is_mode(argc, argv, "sleep"))
        return interrupted();
    if (is_mode(argc, argv, "yield"))
        return scheduler();
    return 90;
}
