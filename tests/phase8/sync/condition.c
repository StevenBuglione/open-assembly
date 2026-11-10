#define _GNU_SOURCE
#include "sync.h"
#include <limits.h>

static int attributes(const char *mode)
{
    pthread_condattr_t attr;
    memset(&attr, 0xa5, sizeof attr);
    clockid_t clock = -99;
    if (!passed(pthread_condattr_init(&attr)))
        return 10;
    if (!strcmp(mode, "attr-init") || !strcmp(mode, "attr-getclock")) {
        if (!passed(pthread_condattr_getclock(&attr, &clock)) || clock != CLOCK_REALTIME)
            return 11;
    } else if (!strcmp(mode, "attr-setclock") || !strcmp(mode, "attr-invalid-clock")) {
        if (!passed(pthread_condattr_setclock(&attr, CLOCK_MONOTONIC)) ||
            !passed(pthread_condattr_getclock(&attr, &clock)) || clock != CLOCK_MONOTONIC)
            return 12;
        if (!strcmp(mode, "attr-invalid-clock") &&
            (!correct(pthread_condattr_setclock(&attr, INT_MAX), EINVAL) ||
             !passed(pthread_condattr_getclock(&attr, &clock)) || clock != CLOCK_MONOTONIC))
            return 13;
    } else if (!strcmp(mode, "attr-destroy")) {
        if (!passed(pthread_condattr_destroy(&attr)))
            return 14;
        return correct(pthread_condattr_destroy(&attr), EINVAL) ? 0 : 15;
    } else {
        return 90;
    }
    return passed(pthread_condattr_destroy(&attr)) ? 0 : 16;
}

static int deadlines(int explicit)
{
    pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    pthread_cond_t cond = PTHREAD_COND_INITIALIZER;
    const struct timespec expired = {0, 0};
    const struct timespec invalid = {0, -1};
    if (!passed(pthread_mutex_lock(&mutex)))
        return 20;
    int timed_out, malformed;
    if (!explicit) {
        timed_out = correct(pthread_cond_timedwait(&cond, &mutex, &expired), ETIMEDOUT);
        malformed = correct(pthread_cond_timedwait(&cond, &mutex, &invalid), EINVAL);
    } else {
#if !defined(OA_PHASE8_HOST) || defined(__GLIBC__)
        timed_out = correct(pthread_cond_clockwait(&cond, &mutex, CLOCK_MONOTONIC, &expired),
                            ETIMEDOUT);
        malformed = correct(pthread_cond_clockwait(&cond, &mutex, CLOCK_MONOTONIC, &invalid),
                            EINVAL);
#else
        return 91;
#endif
    }
    if (!timed_out)
        return 21;
    if (!malformed || !correct(pthread_mutex_trylock(&mutex), EBUSY) ||
        !passed(pthread_mutex_unlock(&mutex)) || !passed(pthread_mutex_destroy(&mutex)) ||
        !passed(pthread_cond_destroy(&cond)))
        return 22;
    return 0;
}

static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t cond;
static unsigned arrived;
static unsigned permits;
static unsigned done;
static int first_finished;
static int plain_wait;

static void *consume(void *argument)
{
    struct timespec deadline;
    if (clock_gettime(CLOCK_MONOTONIC, &deadline))
        return NULL;
    deadline.tv_sec += 2;
    errno = EDOM;
    if (!passed(pthread_mutex_lock(&mutex)))
        return NULL;
    ++arrived;
    /* Predicates handle permitted spurious wakeups. Bound even a zero-return
       stub that never releases the mutex, so rejection remains observable. */
    unsigned attempts = 0;
    int failed = 0;
    while (!permits && attempts++ < 10000) {
        int status = plain_wait ? pthread_cond_wait(&cond, &mutex)
                                : pthread_cond_timedwait(&cond, &mutex, &deadline);
        if (!passed(status)) {
            failed = 1;
            break;
        }
    }
    if (failed || !permits || attempts > 10000) {
        (void)pthread_mutex_unlock(&mutex);
        return NULL;
    }
    --permits;
    ++done;
    mark(&first_finished);
    return passed(pthread_mutex_unlock(&mutex)) ? argument : NULL;
}

static int await_arrivals(unsigned count)
{
    const struct timespec pause = {.tv_nsec = 1000000};
    for (unsigned tries = 0; tries < 1000; ++tries) {
        errno = EDOM;
        if (!passed(pthread_mutex_lock(&mutex)))
            break;
        if (arrived == count)
            return 1;
        if (!passed(pthread_mutex_unlock(&mutex)))
            break;
        (void)nanosleep(&pause, NULL);
    }
    return 0;
}

static int handoff(const char *mode)
{
    pthread_condattr_t attr;
    if (!passed(pthread_condattr_init(&attr)) ||
        !passed(pthread_condattr_setclock(&attr, CLOCK_MONOTONIC)))
        return 30;
    unsigned char original[sizeof cond];
    memset(original, 0xa5, sizeof original);
    memcpy(&cond, original, sizeof cond);
    if (!passed(pthread_cond_init(&cond, &attr)) || !passed(pthread_condattr_destroy(&attr)))
        return 31;
    if (!strcmp(mode, "init")) {
#ifndef OA_PHASE8_HOST
        /* The published object layout stores an initialized condition queue. */
        if (!memcmp(&cond, original, sizeof original))
            return 32;
#endif
        if (!passed(pthread_cond_signal(&cond)))
            return 32;
        return passed(pthread_cond_destroy(&cond)) ? 0 : 33;
    }
    plain_wait = !strcmp(mode, "wait");
    int single = !strcmp(mode, "signal");
    int destroying = !strcmp(mode, "destroy");
    unsigned count = plain_wait ? 1u : 3u;
    pthread_t workers[3];
    int tokens[3];
    for (unsigned i = 0; i < count; ++i) {
        if (!passed(pthread_create(&workers[i], NULL, consume, &tokens[i])))
            return 34;
    }
    if (!await_arrivals(count))
        return 35;
    if (destroying && !correct(pthread_cond_destroy(&cond), EBUSY))
        return 36;
    permits = single ? 1u : count;
    int woke = single ? pthread_cond_signal(&cond) : pthread_cond_broadcast(&cond);
    if (!passed(woke) || !passed(pthread_mutex_unlock(&mutex)))
        return 37;
    if (single) {
        if (waiting(&first_finished))
            return 38;
        errno = EDOM;
        if (!passed(pthread_mutex_lock(&mutex)) || done != 1)
            return 39;
        permits = count - 1;
        if (!passed(pthread_cond_broadcast(&cond)) || !passed(pthread_mutex_unlock(&mutex)))
            return 40;
    }
    for (unsigned i = 0; i < count; ++i) {
        void *result = NULL;
        if (!passed(pthread_join(workers[i], &result)) || result != &tokens[i])
            return 41;
    }
    if (done != count || !passed(pthread_cond_destroy(&cond)) ||
        !passed(pthread_mutex_destroy(&mutex)))
        return 42;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    const char *mode = argv[1];
    errno = EDOM;
    if (!strncmp(mode, "attr-", 5))
        return attributes(mode);
    if (!strcmp(mode, "timedwait") || !strcmp(mode, "clockwait"))
        return deadlines(!strcmp(mode, "clockwait"));
    return handoff(mode);
}
