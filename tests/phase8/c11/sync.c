#define _POSIX_C_SOURCE 200809L
#include "support.h"

struct acquisition {
    mtx_t *mutex;
    int timed;
};

static int attempt_lock(void *opaque)
{
    struct acquisition *work = opaque;
    const struct timespec expired = {0, 0};
    errno = EDOM;
    int status = work->timed ? mtx_timedlock(work->mutex, &expired) : mtx_trylock(work->mutex);
    if (!correct(status, status) || (status == thrd_success && !success(mtx_unlock(work->mutex))))
        return -100;
    return status;
}

static int foreign_result(mtx_t *mutex, int timed, int expected)
{
    struct acquisition work = {mutex, timed};
    thrd_t worker;
    int status = -99;
    return success(thrd_create(&worker, attempt_lock, &work)) &&
           success(thrd_join(worker, &status)) && status == expected;
}

static int locks(const char *mode)
{
    mtx_t mutex;
    memset(&mutex, 0xa5, sizeof mutex);
    int recursive = !strcmp(mode, "recursive");
    int timed = !strcmp(mode, "timedlock");
    if (!success(mtx_init(&mutex, recursive ? mtx_recursive : (timed ? mtx_timed : mtx_plain))))
        return 10;
    if (!strcmp(mode, "mutex-init")) {
        if (!success(mtx_trylock(&mutex)) || !success(mtx_unlock(&mutex)))
            return 11;
    } else if (!strcmp(mode, "lock") || !strcmp(mode, "trylock")) {
        if (!success(mtx_lock(&mutex)) || !foreign_result(&mutex, 0, thrd_busy) ||
            !success(mtx_unlock(&mutex)))
            return 12;
    } else if (!strcmp(mode, "unlock")) {
        if (!success(mtx_lock(&mutex)) || !success(mtx_unlock(&mutex)) ||
            !foreign_result(&mutex, 0, thrd_success))
            return 13;
    } else if (recursive) {
        if (!success(mtx_lock(&mutex)) || !success(mtx_trylock(&mutex)) ||
            !foreign_result(&mutex, 0, thrd_busy) || !success(mtx_unlock(&mutex)) ||
            !foreign_result(&mutex, 0, thrd_busy) || !success(mtx_unlock(&mutex)) ||
            !foreign_result(&mutex, 0, thrd_success))
            return 14;
    } else if (timed) {
        if (!success(mtx_lock(&mutex)) || !foreign_result(&mutex, 1, thrd_timedout) ||
            !success(mtx_unlock(&mutex)) || !foreign_result(&mutex, 1, thrd_success))
            return 15;
    }
    mtx_destroy(&mutex);
#ifndef OA_PHASE8_HOST
    if (!correct(0, 0) || (!strcmp(mode, "mutex-destroy") &&
        !correct(mtx_trylock(&mutex), thrd_error)))
        return 16;
#endif
    return 0;
}

static int condition_direct(int destroyed)
{
    cnd_t condition;
    unsigned char original[sizeof condition];
    memset(original, 0xa5, sizeof original);
    memcpy(&condition, original, sizeof condition);
    if (!success(cnd_init(&condition)))
        return 20;
#ifndef OA_PHASE8_HOST
    if (!memcmp(&condition, original, sizeof original))
        return 20;
#endif
    if (!success(cnd_signal(&condition)))
        return 20;
    cnd_destroy(&condition);
#ifndef OA_PHASE8_HOST
    if (!correct(0, 0) || (destroyed && !correct(cnd_signal(&condition), thrd_error)))
        return 21;
#else
    (void)destroyed;
#endif
    return 0;
}

static int deadline(void)
{
    cnd_t cond;
    mtx_t mutex;
    const struct timespec old = {0, 0};
    if (!success(cnd_init(&cond)) || !success(mtx_init(&mutex, mtx_plain)) ||
        !success(mtx_lock(&mutex)))
        return 23;
    if (!correct(cnd_timedwait(&cond, &mutex, &old), thrd_timedout))
        return 24;
    if (!foreign_result(&mutex, 0, thrd_busy) || !success(mtx_unlock(&mutex)))
        return 25;
    cnd_destroy(&cond);
    mtx_destroy(&mutex);
    return 0;
}

static cnd_t ready;
static mtx_t lock;
static int use_wait;
static int arrivals;
static int permits;
static int one_finished;
static int finished;

static int waiter(void *argument)
{
    struct timespec limit;
    if (timespec_get(&limit, TIME_UTC) != TIME_UTC)
        return 101;
    limit.tv_sec += 2;
    errno = EDOM;
    if (!success(mtx_lock(&lock)))
        return 102;
    ++arrivals;
    int error = 0;
    unsigned attempts = 0;
    while (!permits && attempts++ < 10000) {
        int status = use_wait ? cnd_wait(&ready, &lock) : cnd_timedwait(&ready, &lock, &limit);
        if (!success(status)) {
            error = 1;
            break;
        }
    }
    if (error || !permits || attempts > 10000) {
        (void)mtx_unlock(&lock);
        return 103;
    }
    --permits;
    ++finished;
    mark(&one_finished);
    return success(mtx_unlock(&lock)) ? *(const int *)argument : 104;
}

static int acquire_all(int count)
{
    const struct timespec pause = {.tv_nsec = 1000000};
    for (unsigned tries = 0; tries < 1000; ++tries) {
        errno = EDOM;
        if (!success(mtx_lock(&lock)))
            break;
        if (arrivals == count)
            return 1;
        if (!success(mtx_unlock(&lock)))
            break;
        (void)nanosleep(&pause, NULL);
    }
    return 0;
}

static int handoff(const char *mode)
{
    if (!success(cnd_init(&ready)) || !success(mtx_init(&lock, mtx_plain)))
        return 30;
    use_wait = !strcmp(mode, "wait");
    int single = !strcmp(mode, "signal");
    int count = use_wait ? 1 : 3;
    int expected[] = {-1, -2, -3};
    thrd_t workers[3];
    for (int i = 0; i < count; ++i) {
        if (!success(thrd_create(&workers[i], waiter, &expected[i])))
            return 31;
    }
    if (!acquire_all(count))
        return 32;
    permits = single ? 1 : count;
    if (!success(single ? cnd_signal(&ready) : cnd_broadcast(&ready)) ||
        !success(mtx_unlock(&lock)))
        return 33;
    if (single) {
        if (!wait_for(&one_finished))
            return 34;
        errno = EDOM;
        if (!success(mtx_lock(&lock)) || finished != 1)
            return 35;
        permits = count - 1;
        if (!success(cnd_broadcast(&ready)) || !success(mtx_unlock(&lock)))
            return 36;
    }
    for (int i = 0; i < count; ++i) {
        int result = 0;
        if (!success(thrd_join(workers[i], &result)) || result != expected[i])
            return 37;
    }
    if (finished != count)
        return 38;
    cnd_destroy(&ready);
    mtx_destroy(&lock);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    const char *mode = argv[1];
    errno = EDOM;
    if (!strcmp(mode, "signal") || !strcmp(mode, "broadcast") || !strcmp(mode, "wait"))
        return handoff(mode);
    if (!strcmp(mode, "cond-init") || !strcmp(mode, "cond-destroy"))
        return condition_direct(!strcmp(mode, "cond-destroy"));
    if (!strcmp(mode, "timedwait"))
        return deadline();
    return locks(mode);
}
