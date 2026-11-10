#ifndef OA_PHASE8_C11_SUPPORT_H
#define OA_PHASE8_C11_SUPPORT_H
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <threads.h>
#include <time.h>

static inline int correct(int actual, int expected)
{
#ifdef OA_PHASE8_HOST
    return actual == expected;
#else
    return actual == expected && errno == EDOM;
#endif
}

static inline int success(int actual)
{
    return correct(actual, thrd_success);
}

static inline int is_mode(int argc, char **argv, const char *mode)
{
    return argc == 2 && !strcmp(argv[1], mode);
}

static inline void mark(int *flag)
{
    __atomic_store_n(flag, 1, __ATOMIC_RELEASE);
}

static inline int wait_for(const int *flag)
{
    const struct timespec pause = {.tv_nsec = 1000000};
    for (int attempt = 0; attempt < 3000; ++attempt) {
        if (__atomic_load_n(flag, __ATOMIC_ACQUIRE))
            return 1;
        (void)nanosleep(&pause, NULL);
    }
    return 0;
}

#endif
