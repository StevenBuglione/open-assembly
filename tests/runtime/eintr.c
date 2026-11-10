#include <errno.h>
#include <signal.h>
#include <sys/time.h>
#include <unistd.h>

#include "linux_abi.h"

static volatile sig_atomic_t delivered;
static volatile sig_atomic_t writer;

static void tick(int signal)
{
    if (signal == SIGALRM && ++delivered == 5) {
        /* If read restarts, make it return EOF so the test can reject it. */
        __al_syscall(__NR_close, writer, 0, 0, 0, 0, 0);
    }
}

int main(void)
{
    int ends[2];
    if (__al_syscall(__NR_pipe2, (long)ends, 0, 0, 0, 0, 0) != 0)
        return 20;
    writer = ends[1];
    const struct kernel_sigaction action = {tick, KERNEL_SA_RESTORER, __al_rt_sigreturn, 0};
    if (__al_syscall(__NR_rt_sigaction, SIGALRM, (long)&action, 0, sizeof action.mask, 0, 0) != 0)
        return 21;

    /* Repeating ticks allow for scheduling delays before read starts. */
    const struct itimerval repeat = {{0, 100000}, {0, 100000}};
    if (__al_syscall(__NR_setitimer, ITIMER_REAL, (long)&repeat, 0, 0, 0, 0) != 0)
        return 22;
    char byte = '.';
    errno = 126;
    ssize_t result = read(ends[0], &byte, 1);
    int error = errno;
    const struct itimerval stop = {{0, 0}, {0, 0}};
    if (__al_syscall(__NR_setitimer, ITIMER_REAL, (long)&stop, 0, 0, 0, 0) != 0)
        return 23;
    if (result != -1 || error != EINTR || !delivered || byte != '.')
        return 24;
    return 0;
}
