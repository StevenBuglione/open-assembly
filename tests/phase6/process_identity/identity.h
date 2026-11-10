#ifndef OA_PROCESS_IDENTITY_H
#define OA_PROCESS_IDENTITY_H

#include "../kernel_abi.h"
#include <stdint.h>
#include <sys/wait.h>

_Static_assert(sizeof(pid_t) == 4 && (pid_t)-1 < 0, "Linux LP64 signed pid_t");

static inline long raw_identity(int parent)
{
    return kernel_call(parent ? __NR_getppid : __NR_getpid, 0, 0, 0, 0, 0, 0);
}

static inline long raw_fork_process(void)
{
    return kernel_call(__NR_fork, 0, 0, 0, 0, 0, 0);
}

static inline int raw_wait_status(long child)
{
    int status = 0;
    long observed;
    do {
        observed = kernel_call(__NR_wait4, child, (long)&status, 0, 0, 0, 0);
    } while (observed == -EINTR);
    return observed == child && WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

#endif
