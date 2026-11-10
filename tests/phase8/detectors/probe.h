/* Detector calibration only. Observe three named locks and no other memory. */
#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>

#if defined(OA_HELGRIND)
#include <valgrind/helgrind.h>
#define LOCK_INIT(word) VALGRIND_HG_MUTEX_INIT_POST(word, 0)
#define LOCK_PRE(word) VALGRIND_HG_MUTEX_LOCK_PRE(word, 0)
#define LOCK_POST(word) VALGRIND_HG_MUTEX_LOCK_POST(word)
#define UNLOCK_PRE(word) VALGRIND_HG_MUTEX_UNLOCK_PRE(word)
#define UNLOCK_POST(word) VALGRIND_HG_MUTEX_UNLOCK_POST(word)
#elif defined(OA_DRD)
#include <valgrind/drd.h>
#define LOCK_INIT(word) ANNOTATE_RWLOCK_CREATE(word)
#define LOCK_PRE(word) ((void)(word))
#define LOCK_POST(word) ANNOTATE_RWLOCK_ACQUIRED(word, 1)
#define UNLOCK_PRE(word) ANNOTATE_RWLOCK_RELEASED(word, 1)
#define UNLOCK_POST(word) ((void)(word))
#endif

void __al_lock(unsigned *word);
void __al_unlock(unsigned *word);
void __real___al_lock(unsigned *word);
void __real___al_unlock(unsigned *word);
long __al_syscall(long, long, long, long, long, long, long);

static unsigned lock_words[3];
static unsigned complete[2];
static unsigned stop_word;
static unsigned use_lock;
static volatile unsigned global_counter;

static int tracked(unsigned *word)
{
    return word == lock_words || word == lock_words + 1 || word == lock_words + 2;
}

void __wrap___al_lock(unsigned *word)
{
    if (tracked(word))
        LOCK_PRE(word);
    __real___al_lock(word);
    if (tracked(word))
        LOCK_POST(word);
}

void __wrap___al_unlock(unsigned *word)
{
    if (tracked(word))
        UNLOCK_PRE(word);
    __real___al_unlock(word);
    if (tracked(word))
        UNLOCK_POST(word);
}

static void yield(void)
{
    (void)__al_syscall(24, 0, 0, 0, 0, 0, 0);
}

static _Noreturn void stop_worker(void)
{
    for (;;)
        (void)__al_syscall(202, (long)&stop_word, 128, 0, 0, 0, 0);
}

static void *counter_worker(void *argument)
{
    unsigned index = (unsigned)(unsigned long)argument;
    for (unsigned i = 0; i < 1000; i++) {
        if (use_lock)
            __al_lock(lock_words);
        global_counter++;
        if ((i & 127) == 0)
            yield();
        if (use_lock)
            __al_unlock(lock_words);
    }
    __al_lock(lock_words + index + 1);
    complete[index] = 1;
    __al_unlock(lock_words + index + 1);
    stop_worker();
}

static void wait_for(unsigned index)
{
    for (;;) {
        __al_lock(lock_words + index + 1);
        unsigned ready = complete[index];
        __al_unlock(lock_words + index + 1);
        if (ready)
            return;
        yield();
    }
}

static void check_order(void)
{
    __al_lock(lock_words);
    __al_lock(lock_words + 1);
    __al_unlock(lock_words + 1);
    __al_unlock(lock_words);
    __al_lock(lock_words + 1);
    __al_lock(lock_words);
    __al_unlock(lock_words);
    __al_unlock(lock_words + 1);
}

int main(int argc, char **argv)
{
    if (argc != 2)
        _Exit(2);
    for (unsigned i = 0; i < 3; i++)
        LOCK_INIT(lock_words + i);
    if (argv[1][0] == 'o')
        check_order();
    else {
        pthread_t worker[2];
        use_lock = argv[1][0] == 'l';
        for (unsigned long i = 0; i < 2; i++)
            if (pthread_create(worker + i, 0, counter_worker, (void *)i))
                _Exit(3);
        for (unsigned i = 0; i < 2; i++)
            wait_for(i);
        if (use_lock && global_counter != 2000)
            _Exit(4);
    }
    if (write(1, "detector fixture complete\n", 26) != 26)
        _Exit(5);
    _Exit(0);
}
