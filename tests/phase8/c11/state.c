#define _POSIX_C_SOURCE 200809L
#include "support.h"

static tss_t key;
static int main_value, worker_value;
static int calls, invalid;

static void destructor(void *pointer)
{
    ++calls;
    if (pointer != &worker_value || tss_get(key) || !success(0))
        invalid = 1;
    if (calls < TSS_DTOR_ITERATIONS && !success(tss_set(key, pointer)))
        invalid = 1;
}

static int worker(void *unused)
{
    (void)unused;
    errno = EDOM;
    if (tss_get(key) || !success(tss_set(key, &worker_value)) ||
        tss_get(key) != &worker_value || !success(0))
        return -10;
    return -19;
}

static int specific(const char *mode)
{
    int callbacks = !strcmp(mode, "destructors");
    key = (tss_t)-1;
    if (!success(tss_create(&key, callbacks ? destructor : NULL)) || key == (tss_t)-1)
        return 10;
    if (tss_get(key) || !success(tss_set(key, &main_value)) ||
        tss_get(key) != &main_value || !success(0))
        return 11;
    if (callbacks) {
        thrd_t thread;
        int answer = 0;
        if (!success(thrd_create(&thread, worker, NULL)) ||
            !success(thrd_join(thread, &answer)) || answer != -19)
            return 12;
        if (calls != TSS_DTOR_ITERATIONS || invalid || tss_get(key) != &main_value || !success(0))
            return 13;
    }
    tss_delete(key);
#ifndef OA_PHASE8_HOST
    if (!success(0) || (!strcmp(mode, "delete") &&
        (tss_get(key) != NULL || !correct(tss_set(key, &main_value), thrd_error))))
        return 14;
#endif
    return 0;
}

enum { THREADS = 4, WIDTH = 16 };

static once_flag control = ONCE_FLAG_INIT;
static once_flag secondary = ONCE_FLAG_INIT;
static int visits, table[WIDTH], inside, released, done;
static int entered[THREADS];

static void initialize_secondary(void)
{
    for (int i = 0; i < WIDTH; ++i)
        table[i] = (i + 11) * 3;
}

static void initialize(void)
{
    if (__atomic_fetch_add(&visits, 1, __ATOMIC_RELAXED))
        return;
    mark(&inside);
    if (wait_for(&released))
        call_once(&secondary, initialize_secondary);
}

static int read_once(void *argument)
{
    int i = *(const int *)argument;
    errno = EDOM;
    mark(&entered[i]);
    call_once(&control, initialize);
    __atomic_add_fetch(&done, 1, __ATOMIC_RELEASE);
    for (int j = 0; j < WIDTH; ++j) {
        if (table[j] != (j + 11) * 3)
            return -20;
    }
    return success(0) ? -30 - i : -21;
}

static int once(void)
{
    thrd_t workers[THREADS];
    int index[THREADS];
    for (int i = 0; i < THREADS; ++i) {
        index[i] = i;
        if (!success(thrd_create(&workers[i], read_once, &index[i])))
            return 20;
    }
    for (int i = 0; i < THREADS; ++i) {
        if (!wait_for(&entered[i]))
            return 21;
    }
    if (!wait_for(&inside) || __atomic_load_n(&done, __ATOMIC_ACQUIRE))
        return 22;
    mark(&released);
    for (int i = 0; i < THREADS; ++i) {
        int result = 0;
        if (!success(thrd_join(workers[i], &result)) || result != -30 - i)
            return 23;
    }
    call_once(&control, initialize);
    return visits == 1 && done == THREADS && success(0) ? 0 : 24;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    errno = EDOM;
    if (!strcmp(argv[1], "once"))
        return once();
    return specific(argv[1]);
}
