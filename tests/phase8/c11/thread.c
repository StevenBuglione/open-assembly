#define _POSIX_C_SOURCE 200809L
#include "support.h"
#include <limits.h>
#include <stdint.h>
#include <unistd.h>

static _Thread_local int local = 77;
static int started;
static int released;
static thrd_t starter;
static thrd_t created;
static thrd_t observed;
static int identity_inside;

static int work(void *arg)
{
    errno = EDOM;
    if (local != 77)
        return 101;
    local = -99;
    observed = thrd_current();
    mark(&started);
    if (!wait_for(&released))
        return 102;
    identity_inside = thrd_equal(observed, thrd_current()) != 0 &&
                      thrd_equal(observed, starter) == 0;
    return local == -99 && errno == EDOM ? *(const int *)arg : 103;
}

#ifndef OA_PHASE8_HOST
static int check_published(void *arg)
{
    thrd_t *output = arg;
    return thrd_equal(*output, thrd_current()) ? INT_MIN : 104;
}
#endif

static int ordinary(const char *mode)
{
    int answer = INT_MIN + 42;
    starter = thrd_current();
#ifndef OA_PHASE8_HOST
    if (!starter)
        return 11;
#endif
    if (!thrd_equal(starter, thrd_current()))
        return 12;
    local = 903;
    created = starter;
    if (!success(thrd_create(&created, work, &answer)) || thrd_equal(created, starter))
        return 13;
    if (!wait_for(&started))
        return 14;
    if (!thrd_equal(created, observed) || thrd_equal(created, starter) || local != 903)
        return 15;
    mark(&released);
    struct { uint32_t before; int result; uint32_t after; } output =
        {0x01234567, 0x123456, 0x89abcdef};
    if (!success(thrd_join(created, &output.result)) || output.result != answer ||
        output.before != 0x01234567 || output.after != 0x89abcdef ||
        local != 903 || !success(0))
        return 16;
#ifndef OA_PHASE8_HOST
    if (!strcmp(mode, "published")) {
        if (!success(thrd_create(&created, check_published, &created)) ||
            !success(thrd_join(created, &output.result)) || output.result != INT_MIN)
            return 17;
    }
#else
    (void)mode;
#endif
    return identity_inside ? 0 : 18;
}

static int exit_routine(void *arg)
{
    thrd_exit(*(const int *)arg);
}

static int exit_test(void)
{
    int answer = -0x62411834;
    int result = 0;
    if (!success(thrd_create(&created, exit_routine, &answer)) ||
        !success(thrd_join(created, &result)) || result != answer)
        return 20;
    static const char output[] = "thread result\n";
    return write(STDOUT_FILENO, output, sizeof output - 1) == sizeof output - 1 ? 0 : 21;
}

static int sleeping(void)
{
    const struct timespec duration = {.tv_nsec = 3000000};
    struct timespec remainder = {.tv_sec = 8, .tv_nsec = 9}, start, finish;
    if (clock_gettime(CLOCK_MONOTONIC, &start))
        return 30;
    errno = EDOM;
    if (!correct(thrd_sleep(&duration, &remainder), 0) ||
        clock_gettime(CLOCK_MONOTONIC, &finish))
        return 31;
    long elapsed = (finish.tv_sec - start.tv_sec) * 1000000000L +
                   (finish.tv_nsec - start.tv_nsec);
    if (elapsed < duration.tv_nsec)
        return 32;
#ifndef OA_PHASE8_HOST
    const struct timespec invalid = {.tv_nsec = 1000000000};
    if (remainder.tv_sec != 8 || remainder.tv_nsec != 9 ||
        !correct(thrd_sleep(&invalid, &remainder), -2) ||
        remainder.tv_sec != 8 || remainder.tv_nsec != 9)
        return 33;
#endif
    return 0;
}

int main(int argc, char **argv)
{
    errno = EDOM;
    if (is_mode(argc, argv, "exit"))
        return exit_test();
    if (is_mode(argc, argv, "sleep"))
        return sleeping();
    if (argc == 2)
        return ordinary(argv[1]);
    return 90;
}
