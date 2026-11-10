#include "../kernel_abi.h"
#include <signal.h>
#include <stdint.h>
#include <time.h>

_Static_assert(sizeof(time_t) == 8 && (time_t)-1 < 0, "signed 64-bit time_t");
_Static_assert(sizeof(clock_t) == 8 && (clock_t)-1 < 0, "signed 64-bit clock_t");
_Static_assert(sizeof(clockid_t) == 4 && (clockid_t)-1 < 0, "signed 32-bit clock ID");
_Static_assert(sizeof(struct timespec) == 16 && _Alignof(struct timespec) == 8, "timespec ABI");
_Static_assert(offsetof(struct timespec, tv_sec) == 0 && offsetof(struct timespec, tv_nsec) == 8,
               "timespec field offsets");
_Static_assert(CLOCKS_PER_SEC == 1000000, "clock microseconds");

static const long billion = 1000000000;
enum { invalid_clock = 2147483647 };

struct boxed_time {
    unsigned long before;
    struct timespec value;
    unsigned long after;
};

static struct boxed_time fresh(void)
{
    return (struct boxed_time){0x1122334455667788UL, {777, 888}, 0x8877665544332211UL};
}

static int canaries(const struct boxed_time *box)
{
    return box->before == 0x1122334455667788UL && box->after == 0x8877665544332211UL;
}

static int same_time(struct timespec a, struct timespec b)
{
    return a.tv_sec == b.tv_sec && a.tv_nsec == b.tv_nsec;
}

static int well_formed(struct timespec value)
{
    return value.tv_nsec >= 0 && value.tv_nsec < billion;
}

static int at_most(struct timespec a, struct timespec b)
{
    return a.tv_sec < b.tv_sec || (a.tv_sec == b.tv_sec && a.tv_nsec <= b.tv_nsec);
}

static long raw_time(int clock_id, struct timespec *result)
{
    return kernel_call(__NR_clock_gettime, clock_id, (long)result, 0, 0, 0, 0);
}

static long raw_resolution(int clock_id, struct timespec *result)
{
    return kernel_call(__NR_clock_getres, clock_id, (long)result, 0, 0, 0, 0);
}

static int elapsed_at_least(struct timespec first, struct timespec last, long ns)
{
    return (last.tv_sec - first.tv_sec) * billion + last.tv_nsec - first.tv_nsec >= ns;
}

static struct timespec add_nanoseconds(struct timespec value, long ns)
{
    value.tv_nsec += ns;
    if (value.tv_nsec >= billion) {
        ++value.tv_sec;
        value.tv_nsec -= billion;
    }
    return value;
}

static int clock_case(void)
{
    struct timespec before, after;
    if (raw_time(CLOCK_PROCESS_CPUTIME_ID, &before))
        return 10;
    errno = TEST_ERRNO;
    clock_t observed = clock();
    if (raw_time(CLOCK_PROCESS_CPUTIME_ID, &after))
        return 12;
    long min = before.tv_sec * 1000000 + before.tv_nsec / 1000;
    long max = after.tv_sec * 1000000 + after.tv_nsec / 1000;
    if (min <= 0)
        return 13;
    return observed < min || observed > max || errno != TEST_ERRNO ? 11 : 0;
}

static int time_case(void)
{
    struct timespec before, after;
    if (raw_time(CLOCK_REALTIME, &before))
        return 20;
    time_t stored = -77;
    errno = TEST_ERRNO;
    time_t observed = time(&stored);
    time_t second = time(NULL);
    if (raw_time(CLOCK_REALTIME, &after))
        return 22;
    if (observed != stored || observed < before.tv_sec || observed > after.tv_sec ||
        second < before.tv_sec || second > after.tv_sec || errno != TEST_ERRNO)
        return 21;
    return 0;
}

static int timespec_case(void)
{
    struct boxed_time box = fresh();
    struct timespec before, after;
    errno = TEST_ERRNO;
#if defined(OA_PHASE6_HOST) && defined(__GLIBC__)
    int unsupported_errno = EINVAL;
#else
    int unsupported_errno = TEST_ERRNO;
#endif
    if (timespec_get(&box.value, 1234) != 0 || !same_time(box.value, fresh().value) ||
        !canaries(&box) || errno != unsupported_errno)
        return 30;
    if (raw_time(CLOCK_REALTIME, &before))
        return 32;
    errno = TEST_ERRNO;
    if (timespec_get(&box.value, TIME_UTC) != TIME_UTC || errno != TEST_ERRNO ||
        !canaries(&box) || !well_formed(box.value))
        return 31;
    if (raw_time(CLOCK_REALTIME, &after) || !at_most(before, box.value) || !at_most(box.value, after))
        return 33;
    return 0;
}

static int gettime_case(void)
{
    const int clocks[] = {CLOCK_REALTIME, CLOCK_MONOTONIC, CLOCK_PROCESS_CPUTIME_ID,
                          CLOCK_THREAD_CPUTIME_ID, CLOCK_MONOTONIC_RAW, CLOCK_BOOTTIME};
    for (size_t i = 0; i < sizeof clocks / sizeof clocks[0]; ++i) {
        struct timespec before, after;
        struct boxed_time box = fresh();
        if (raw_time(clocks[i], &before))
            return 40;
        errno = TEST_ERRNO;
        if (clock_gettime(clocks[i], &box.value) || errno != TEST_ERRNO ||
            !canaries(&box) || !well_formed(box.value))
            return 41;
        if (raw_time(clocks[i], &after) || !at_most(before, box.value) || !at_most(box.value, after))
            return 42;
    }
    struct boxed_time box = fresh();
    if (clock_gettime(invalid_clock, &box.value) != -1 || errno != EINVAL ||
        !canaries(&box) || !same_time(box.value, fresh().value))
        return 43;
    return 0;
}

static int getres_case(void)
{
    const int clocks[] = {CLOCK_REALTIME, CLOCK_MONOTONIC, CLOCK_PROCESS_CPUTIME_ID,
                          CLOCK_THREAD_CPUTIME_ID, CLOCK_MONOTONIC_COARSE, CLOCK_BOOTTIME};
    for (size_t i = 0; i < sizeof clocks / sizeof clocks[0]; ++i) {
        struct timespec expected;
        struct boxed_time box = fresh();
        if (raw_resolution(clocks[i], &expected))
            return 50;
        errno = TEST_ERRNO;
        if (clock_getres(clocks[i], &box.value) || errno != TEST_ERRNO ||
            !canaries(&box) || !same_time(box.value, expected))
            return 51;
        if (clock_getres(clocks[i], NULL) || errno != TEST_ERRNO)
            return 52;
    }
    struct boxed_time box = fresh();
    if (clock_getres(invalid_clock, &box.value) != -1 || errno != EINVAL ||
        !canaries(&box) || !same_time(box.value, fresh().value))
        return 53;
    return 0;
}

static int nanosleep_case(void)
{
    const struct timespec invalid = {0, 1000000000};
    if (nanosleep(&invalid, NULL) != -1 || errno != EINVAL)
        return 61;
    const struct timespec request = {0, 3000000};
    struct timespec before, after;
    if (raw_time(CLOCK_MONOTONIC, &before))
        return 62;
    errno = TEST_ERRNO;
    if (nanosleep(&request, NULL) || errno != TEST_ERRNO ||
        raw_time(CLOCK_MONOTONIC, &after) ||
        !elapsed_at_least(before, after, request.tv_nsec))
        return 63;
    return 0;
}

static int clock_nanosleep_case(void)
{
    const struct timespec invalid = {0, -1};
    errno = TEST_ERRNO;
    if (clock_nanosleep(CLOCK_MONOTONIC, 0, &invalid, NULL) != EINVAL || errno != TEST_ERRNO)
        return 71;
    const struct timespec request = {0, 3000000};
    struct timespec before, after;
    if (raw_time(CLOCK_MONOTONIC, &before))
        return 72;
    if (clock_nanosleep(CLOCK_MONOTONIC, 0, &request, NULL) || errno != TEST_ERRNO ||
        raw_time(CLOCK_MONOTONIC, &after) ||
        !elapsed_at_least(before, after, request.tv_nsec))
        return 73;
    struct timespec deadline = add_nanoseconds(after, request.tv_nsec);
    struct boxed_time remaining = fresh();
    if (clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &deadline, &remaining.value) ||
        errno != TEST_ERRNO || raw_time(CLOCK_MONOTONIC, &after) ||
        !at_most(deadline, after) || !canaries(&remaining) || !same_time(remaining.value, fresh().value))
        return 74;
    return 0;
}

static volatile sig_atomic_t interruptions;

static void count_interrupt(int number)
{
    if (number == SIGALRM)
        ++interruptions;
}

static int configure_timer(int enabled)
{
    /* Linux ITIMER_REAL and two LP64 timeval records, in microseconds. */
    long timer[4] = {0, enabled ? 20000 : 0, 0, enabled ? 20000 : 0};
    return (int)kernel_call(__NR_setitimer, 0, (long)timer, 0, 0, 0, 0);
}

static int interrupted_case(int kind)
{
    struct sigaction action = {0};
    action.sa_handler = count_interrupt;
    if (sigemptyset(&action.sa_mask) || sigaction(SIGALRM, &action, NULL))
        return 80;
    struct timespec request = {1, 0};
    if (kind == 2) {
        if (raw_time(CLOCK_MONOTONIC, &request))
            return 81;
        ++request.tv_sec;
    }
    struct boxed_time remaining = fresh();
    if (configure_timer(1))
        return 82;
    errno = TEST_ERRNO;
    int result = kind == 0 ? nanosleep(&request, &remaining.value) :
        clock_nanosleep(CLOCK_MONOTONIC, kind == 2 ? TIMER_ABSTIME : 0, &request, &remaining.value);
    int error = errno;
    if (configure_timer(0) || !interruptions || !canaries(&remaining))
        return 83;
    if (kind == 0 ? result != -1 || error != EINTR : result != EINTR || error != TEST_ERRNO)
        return 84;
    if (kind == 2)
        return same_time(remaining.value, fresh().value) ? 0 : 85;
    return remaining.value.tv_sec != 0 || remaining.value.tv_nsec <= 0 ||
           remaining.value.tv_nsec >= billion ? 86 : 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    const char *mode = argv[1];
    if (same_text(mode, "clock")) return clock_case();
    if (same_text(mode, "time")) return time_case();
    if (same_text(mode, "timespec-get")) return timespec_case();
    if (same_text(mode, "gettime")) return gettime_case();
    if (same_text(mode, "getres")) return getres_case();
    if (same_text(mode, "nanosleep")) return nanosleep_case();
    if (same_text(mode, "clock-nanosleep")) return clock_nanosleep_case();
    if (same_text(mode, "interrupt-nanosleep")) return interrupted_case(0);
    if (same_text(mode, "interrupt-clock-relative")) return interrupted_case(1);
    if (same_text(mode, "interrupt-clock-absolute")) return interrupted_case(2);
    return 2;
}
