#ifndef OA_PHASE8_SYNC_H
#define OA_PHASE8_SYNC_H
#include <errno.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static inline int correct(int status, int expected)
{
#ifdef OA_PHASE8_HOST
    return status == expected;
#else
    return status == expected && errno == EDOM;
#endif
}

static inline int passed(int status)
{
    return correct(status, 0);
}

static inline void mark(int *flag)
{
    __atomic_store_n(flag, 1, __ATOMIC_RELEASE);
}

static inline int waiting(const int *flag)
{
    const struct timespec sleep = {.tv_nsec = 1000000};
    for (int tries = 0; tries < 2000; ++tries) {
        if (__atomic_load_n(flag, __ATOMIC_ACQUIRE))
            return 0;
        (void)nanosleep(&sleep, NULL);
    }
    return 1;
}

static inline int selection(int argc, char **argv, const char *mode)
{
    return argc == 2 && !strcmp(argv[1], mode);
}

#endif
