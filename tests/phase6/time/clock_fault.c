#include "../kernel_abi.h"
#include <limits.h>
#include <time.h>

enum fault { none, truncation, cpu_overflow, cpu_error, realtime_wide, realtime_error };
static enum fault armed;
static unsigned injections;
extern void *__al_auxv;

long __real___al_syscall(long, long, long, long, long, long, long);

long __wrap___al_syscall(long nr, long a1, long a2, long a3, long a4, long a5, long a6)
{
    int cpu = armed >= truncation && armed <= cpu_error;
    int realtime = armed >= realtime_wide && armed <= realtime_error;
    if (nr != __NR_clock_gettime || !a2 ||
        !((cpu && a1 == CLOCK_PROCESS_CPUTIME_ID) || (realtime && a1 == CLOCK_REALTIME)))
        return __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
    enum fault current = armed;
    armed = none;
    ++injections;
    if (current == cpu_error || current == realtime_error)
        return -EINVAL;
    struct timespec *result = (struct timespec *)a2;
    if (current == truncation) {
        result->tv_sec = 2;
        result->tv_nsec = 987654321;
    } else if (current == cpu_overflow) {
        result->tv_sec = LONG_MAX / 1000000 + 1;
        result->tv_nsec = 0;
    } else {
        result->tv_sec = (1L << 40) + 123;
        result->tv_nsec = 765432109;
    }
    return 0;
}

int main(void)
{
    armed = truncation;
    errno = TEST_ERRNO;
    if (clock() != 2987654 || errno != TEST_ERRNO || armed != none || injections != 1)
        return 10;
    armed = cpu_overflow;
    if (clock() != -1 || errno != EOVERFLOW || armed != none || injections != 2)
        return 11;
    armed = cpu_error;
    if (clock() != -1 || errno != EINVAL || armed != none || injections != 3)
        return 12;

    time_t stored = -17;
    armed = realtime_wide;
    errno = TEST_ERRNO;
    /* Resolve the realtime cache on its raw path, then restore startup auxv. */
    void *saved_auxv = __al_auxv;
    __al_auxv = NULL;
    time_t actual = time(&stored);
    __al_auxv = saved_auxv;
    if (actual != (1L << 40) + 123 || stored != (1L << 40) + 123 ||
        errno != TEST_ERRNO || armed != none || injections != 4)
        return 13;
    stored = -19;
    armed = realtime_error;
    if (time(&stored) != -1 || stored != -19 || errno != EINVAL || armed != none || injections != 5)
        return 14;

    struct timespec value = {111, 222};
    armed = realtime_error;
    errno = TEST_ERRNO;
    if (timespec_get(&value, TIME_UTC) != 0 || errno != EINVAL ||
        value.tv_sec != 111 || value.tv_nsec != 222 || armed != none || injections != 6)
        return 15;
    return 0;
}
