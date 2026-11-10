#define _GNU_SOURCE
#include "sync.h"
#include <limits.h>

static int attributes(const char *mode)
{
    pthread_mutexattr_t attr;
    memset(&attr, 0xa5, sizeof attr);
    int type = -99;
    if (!passed(pthread_mutexattr_init(&attr)))
        return 10;
    if (!strcmp(mode, "attr-init") || !strcmp(mode, "attr-gettype")) {
        if (!passed(pthread_mutexattr_gettype(&attr, &type)) || type != PTHREAD_MUTEX_DEFAULT)
            return 11;
    } else if (!strcmp(mode, "attr-settype")) {
        if (!passed(pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)) ||
            !passed(pthread_mutexattr_gettype(&attr, &type)) || type != PTHREAD_MUTEX_RECURSIVE)
            return 12;
        if (!correct(pthread_mutexattr_settype(&attr, INT_MAX), EINVAL) ||
            !passed(pthread_mutexattr_gettype(&attr, &type)) || type != PTHREAD_MUTEX_RECURSIVE)
            return 13;
    } else if (!strcmp(mode, "attr-destroy")) {
        if (!passed(pthread_mutexattr_destroy(&attr)))
            return 14;
        return correct(pthread_mutexattr_destroy(&attr), EINVAL) ? 0 : 15;
    } else {
        return 90;
    }
    return passed(pthread_mutexattr_destroy(&attr)) ? 0 : 16;
}

static int make_mutex(pthread_mutex_t *mutex, int type)
{
    pthread_mutexattr_t attr;
    return passed(pthread_mutexattr_init(&attr)) &&
           passed(pthread_mutexattr_settype(&attr, type)) &&
           passed(pthread_mutex_init(mutex, &attr)) &&
           passed(pthread_mutexattr_destroy(&attr));
}

static int basics(const char *mode)
{
    pthread_mutex_t mutex;
    memset(&mutex, 0xa5, sizeof mutex);
    if (!passed(pthread_mutex_init(&mutex, NULL)))
        return 30;
    if (!strcmp(mode, "init")) {
        if (!passed(pthread_mutex_trylock(&mutex)) || !passed(pthread_mutex_unlock(&mutex)))
            return 31;
    } else if (!strcmp(mode, "lock") || !strcmp(mode, "trylock")) {
        if (!passed(pthread_mutex_lock(&mutex)) ||
            !correct(pthread_mutex_trylock(&mutex), EBUSY))
            return 34;
        if (!passed(pthread_mutex_unlock(&mutex)))
            return 35;
    } else if (!strcmp(mode, "unlock")) {
        if (!passed(pthread_mutex_lock(&mutex)) || !passed(pthread_mutex_unlock(&mutex)) ||
            !passed(pthread_mutex_trylock(&mutex)))
            return 36;
        if (!passed(pthread_mutex_unlock(&mutex)))
            return 37;
    } else if (!strcmp(mode, "destroy")) {
        if (!passed(pthread_mutex_lock(&mutex)) ||
            !correct(pthread_mutex_destroy(&mutex), EBUSY) || !passed(pthread_mutex_unlock(&mutex)))
            return 38;
    } else {
        return 90;
    }
    return passed(pthread_mutex_destroy(&mutex)) ? 0 : 39;
}

struct contender {
    pthread_mutex_t *mutex;
    int result;
    int foreign;
};

static void *compete(void *opaque)
{
    struct contender *test = opaque;
    errno = EDOM;
    int status = test->foreign ? pthread_mutex_unlock(test->mutex)
                               : pthread_mutex_trylock(test->mutex);
    test->result = correct(status, test->foreign ? EPERM : EBUSY);
    if (!status && !test->foreign)
        (void)pthread_mutex_unlock(test->mutex);
    return test;
}

static int busy_worker(pthread_mutex_t *mutex, int foreign)
{
    struct contender test = {mutex, 0, foreign};
    pthread_t worker;
    void *result = NULL;
    return passed(pthread_create(&worker, NULL, compete, &test)) &&
           passed(pthread_join(worker, &result)) && result == &test && test.result;
}

static int recursive(void)
{
    pthread_mutex_t mutex;
    if (!make_mutex(&mutex, PTHREAD_MUTEX_RECURSIVE) ||
        !passed(pthread_mutex_lock(&mutex)) || !passed(pthread_mutex_trylock(&mutex)) ||
        !passed(pthread_mutex_lock(&mutex)) || !busy_worker(&mutex, 0))
        return 40;
    for (int level = 0; level < 2; ++level) {
        if (!passed(pthread_mutex_unlock(&mutex)) || !busy_worker(&mutex, 0))
            return 41;
    }
    if (!passed(pthread_mutex_unlock(&mutex)) || !passed(pthread_mutex_trylock(&mutex)) ||
        !passed(pthread_mutex_unlock(&mutex)) || !passed(pthread_mutex_destroy(&mutex)))
        return 42;
    return 0;
}

static int ownership(void)
{
    pthread_mutex_t mutex;
    if (!make_mutex(&mutex, PTHREAD_MUTEX_ERRORCHECK) || !passed(pthread_mutex_lock(&mutex)) ||
        !correct(pthread_mutex_lock(&mutex), EDEADLK) ||
        !correct(pthread_mutex_trylock(&mutex), EBUSY) || !busy_worker(&mutex, 1))
        return 43;
    if (!passed(pthread_mutex_unlock(&mutex)) ||
        !correct(pthread_mutex_unlock(&mutex), EPERM) || !passed(pthread_mutex_destroy(&mutex)))
        return 44;
    return 0;
}

static pthread_mutex_t shared_lock = PTHREAD_MUTEX_INITIALIZER;
static unsigned counter;
static int start;

static void *increment(void *argument)
{
    if (waiting(&start))
        return NULL;
    errno = EDOM;
    for (unsigned i = 0; i < 2000; ++i) {
        if (!passed(pthread_mutex_lock(&shared_lock)))
            return NULL;
        ++counter;
        if (!passed(pthread_mutex_unlock(&shared_lock)))
            return NULL;
    }
    return argument;
}

static int contention(void)
{
    enum { THREADS = 4 };
    pthread_t workers[THREADS];
    int tokens[THREADS];
    for (unsigned i = 0; i < THREADS; ++i) {
        if (!passed(pthread_create(&workers[i], NULL, increment, &tokens[i])))
            return 45;
    }
    mark(&start);
    for (unsigned i = 0; i < THREADS; ++i) {
        void *result = NULL;
        if (!passed(pthread_join(workers[i], &result)) || result != &tokens[i])
            return 46;
    }
    return counter == THREADS * 2000 && passed(pthread_mutex_destroy(&shared_lock)) ? 0 : 47;
}

static int timed(pthread_mutex_t *mutex, int explicit, const struct timespec *when)
{
    if (!explicit)
        return pthread_mutex_timedlock(mutex, when);
#if !defined(OA_PHASE8_HOST) || defined(__GLIBC__)
    return pthread_mutex_clocklock(mutex, CLOCK_MONOTONIC, when);
#else
    return ENOSYS;
#endif
}

static int deadlines(int explicit)
{
    pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
    const struct timespec expired = {0, 0};
    const struct timespec bad = {0, 1000000000};
    if (!passed(timed(&mutex, explicit, &bad)))
        return 50;
    if (!correct(timed(&mutex, explicit, &expired), ETIMEDOUT))
        return 51;
    if (!correct(timed(&mutex, explicit, &bad), EINVAL))
        return 52;
    if (!passed(pthread_mutex_unlock(&mutex)) ||
        !passed(timed(&mutex, explicit, &expired)) || !passed(pthread_mutex_unlock(&mutex)) ||
        !passed(pthread_mutex_destroy(&mutex)))
        return 53;
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
    if (!strcmp(mode, "recursive"))
        return recursive();
    if (!strcmp(mode, "ownership"))
        return ownership();
    if (!strcmp(mode, "contention"))
        return contention();
    if (!strcmp(mode, "timedlock") || !strcmp(mode, "clocklock"))
        return deadlines(!strcmp(mode, "clocklock"));
    return basics(mode);
}
