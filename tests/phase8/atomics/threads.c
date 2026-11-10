#include <compiler_rt.h>
#include <errno.h>
#include <pthread.h>
#include <stdint.h>

typedef unsigned __int128 wide;

enum { THREADS = 4, ROUNDS = 4096 };
static _Alignas(16) wide wide_counter;
static _Alignas(8) uint64_t narrow_counter;
static unsigned ready;

struct worker_args { unsigned index; int passed; };

static void *worker(void *argument)
{
    struct worker_args *args = argument;
    __atomic_fetch_add(&ready, 1, __ATOMIC_SEQ_CST);
    while (__atomic_load_n(&ready, __ATOMIC_SEQ_CST) != THREADS)
        __asm__ volatile ("pause");

    errno = EDOM;
    for (unsigned i = 0; i < ROUNDS; ++i) {
        if (args->index % 2) {
            __atomic_fetch_add(&narrow_counter, 1, __ATOMIC_SEQ_CST);
            __al_abi_atomic_fetch_add_16(&wide_counter, 1, __ATOMIC_SEQ_CST);
        } else {
            uint64_t narrow;
            __al_abi_atomic_load(sizeof narrow, &narrow_counter, &narrow, __ATOMIC_SEQ_CST);
            for (;;) {
                uint64_t next = narrow + 1;
                if (__al_abi_atomic_compare_exchange(sizeof narrow, &narrow_counter, &narrow,
                                                       &next, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST))
                    break;
            }
            wide large;
            __al_abi_atomic_load(sizeof large, &wide_counter, &large, __ATOMIC_SEQ_CST);
            for (;;) {
                wide next = large + 1;
                if (__al_abi_atomic_compare_exchange(sizeof large, &wide_counter, &large,
                                                       &next, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST))
                    break;
            }
        }
        if (errno != EDOM)
            return NULL;
    }
    args->passed = 1;
    return args;
}

int main(void)
{
    const wide initial = ((wide)5 << 64) + UINT64_MAX - 17;
    wide_counter = initial;
    narrow_counter = UINT64_MAX - 13;
    pthread_t threads[THREADS];
    struct worker_args arguments[THREADS];
    for (unsigned i = 0; i < THREADS; ++i) {
        arguments[i] = (struct worker_args){i, 0};
        if (pthread_create(&threads[i], NULL, worker, &arguments[i]))
            return 90;
    }
    for (unsigned i = 0; i < THREADS; ++i) {
        void *result = NULL;
        if (pthread_join(threads[i], &result) || result != &arguments[i] || !arguments[i].passed)
            return 11;
    }
    return narrow_counter == (uint64_t)(UINT64_MAX - 13 + (uint64_t)THREADS * ROUNDS) &&
           wide_counter == initial + THREADS * ROUNDS ? 0 : 12;
}
