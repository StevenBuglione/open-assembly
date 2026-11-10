#define _POSIX_C_SOURCE 200809L
#include "sync.h"

enum { THREADS = 6, WIDTH = 32 };

static pthread_once_t control = PTHREAD_ONCE_INIT;
static pthread_once_t nested = PTHREAD_ONCE_INIT;
static int attempts;
static int inside;
static int release;
static int entered[THREADS];
static int returns;
static int table[WIDTH];
static int callback_failed;
static int token;

static void inner(void)
{
    for (unsigned i = 0; i < WIDTH; ++i)
        table[i] = (int)(3 * i + 11);
}

static void initialize(void)
{
    if (__atomic_fetch_add(&attempts, 1, __ATOMIC_RELAXED) != 0)
        return;
    mark(&inside);
    if (waiting(&release) || pthread_once(&nested, inner))
        callback_failed = 1;
}

static void *consumer(void *argument)
{
    int index = *(const int *)argument;
    errno = EDOM;
    mark(&entered[index]);
    int status = pthread_once(&control, initialize);
    __atomic_add_fetch(&returns, 1, __ATOMIC_RELEASE);
    if (!passed(status))
        return NULL;
    for (unsigned i = 0; i < WIDTH; ++i) {
        if (table[i] != (int)(3 * i + 11))
            return NULL;
    }
    return argument;
}

static int publication(void)
{
    pthread_t threads[THREADS];
    int index[THREADS];
    for (int i = 0; i < THREADS; ++i) {
        index[i] = i;
        if (!passed(pthread_create(&threads[i], NULL, consumer, &index[i])))
            return 10;
    }
    for (int i = 0; i < THREADS; ++i) {
        if (waiting(&entered[i]))
            return 11;
    }
    if (waiting(&inside) || __atomic_load_n(&returns, __ATOMIC_ACQUIRE))
        return 12;
    mark(&release);
    for (int i = 0; i < THREADS; ++i) {
        void *result = NULL;
        if (!passed(pthread_join(threads[i], &result)) || result != &index[i])
            return 13;
    }
    if (!passed(pthread_once(&control, initialize)) || attempts != 1 || callback_failed ||
        returns != THREADS)
        return 14;
    return 0;
}

static void interrupted_initializer(void)
{
    if (++attempts == 1)
        pthread_exit(&token);
    inner();
}

static void *leave(void *unused)
{
    (void)unused;
    (void)pthread_once(&control, interrupted_initializer);
    return NULL;
}

static int restart(void)
{
    pthread_t thread;
    void *result = NULL;
    if (!passed(pthread_create(&thread, NULL, leave, NULL)) ||
        !passed(pthread_join(thread, &result)) || result != &token || attempts != 1)
        return 21;
    if (!passed(pthread_once(&control, interrupted_initializer)) ||
        !passed(pthread_once(&control, interrupted_initializer)) || attempts != 2 ||
        table[31] != 104)
        return 22;
    return 0;
}

int main(int argc, char **argv)
{
    errno = EDOM;
    if (selection(argc, argv, "publication"))
        return publication();
    if (selection(argc, argv, "restart"))
        return restart();
    return 90;
}
