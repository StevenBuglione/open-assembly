#include "../kernel_abi.h"
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>

enum probe { none, fork_error, interrupted_wait, system_wait };
static enum probe armed;
static unsigned fork_hits, wait_hits, observed_system_state;

long __real___al_syscall(long, long, long, long, long, long, long);

long __wrap___al_syscall(long nr, long a1, long a2, long a3, long a4, long a5, long a6)
{
    if (armed == fork_error && (nr == __NR_fork || nr == __NR_vfork || nr == __NR_clone)) {
        armed = none;
        ++fork_hits;
        return -EAGAIN;
    }
    if (nr == __NR_wait4 && a1 > 0) {
        if (armed == interrupted_wait && ++wait_hits == 1)
            return -EINTR;
        if (armed == system_wait) {
            unsigned long interrupt[4], quit[4];
            uint64_t mask = 0;
            if (!__real___al_syscall(__NR_rt_sigaction, SIGINT, 0, (long)interrupt, 8, 0, 0) &&
                !__real___al_syscall(__NR_rt_sigaction, SIGQUIT, 0, (long)quit, 8, 0, 0) &&
                !__real___al_syscall(__NR_rt_sigprocmask, SIG_SETMASK, 0, (long)&mask, 8, 0, 0) &&
                interrupt[0] == (uintptr_t)SIG_IGN && quit[0] == (uintptr_t)SIG_IGN &&
                (mask & (UINT64_C(1) << (SIGCHLD - 1))))
                ++observed_system_state;
        }
    }
    return __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
}

static uint64_t descriptor_set(void)
{
    uint64_t set = 0;
    for (int fd = 3; fd < 64; ++fd) {
        if (raw_fcntl(fd, K_F_GETFD, 0) >= 0)
            set |= UINT64_C(1) << fd;
    }
    return set;
}

static int fork_case(void)
{
    uint64_t before = descriptor_set(), original_mask = 0, final_mask = 0;
    unsigned long original[4], final[4];
    if (kernel_call(__NR_rt_sigprocmask, SIG_SETMASK, 0, (long)&original_mask, 8, 0, 0) ||
        kernel_call(__NR_rt_sigaction, SIGINT, 0, (long)original, 8, 0, 0))
        return 10;
    armed = fork_error;
    if (system("exit 0") != -1 || errno != EAGAIN || fork_hits != 1 || armed != none)
        return 11;
    if (kernel_call(__NR_rt_sigprocmask, SIG_SETMASK, 0, (long)&final_mask, 8, 0, 0) ||
        kernel_call(__NR_rt_sigaction, SIGINT, 0, (long)final, 8, 0, 0) || final_mask != original_mask)
        return 12;
    for (unsigned i = 0; i < 4; ++i) {
        if (original[i] != final[i])
            return 13;
    }
    armed = fork_error;
    if (popen("exit 0", "r") || errno != EAGAIN || fork_hits != 2 || armed != none ||
        descriptor_set() != before)
        return 14;
    return 0;
}

static int wait_case(void)
{
    FILE *stream = popen("exit 19", "r");
    if (!stream)
        return 20;
    armed = interrupted_wait;
    int status = pclose(stream);
    armed = none;
    if (status != (19 << 8) || wait_hits < 2)
        return 21;
    armed = system_wait;
    status = system("exit 24");
    armed = none;
    return status != (24 << 8) || !observed_system_state ? 22 : 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    if (same_text(argv[1], "fork")) return fork_case();
    if (same_text(argv[1], "wait")) return wait_case();
    return 2;
}
