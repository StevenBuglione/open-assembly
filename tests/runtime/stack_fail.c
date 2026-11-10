#define _POSIX_C_SOURCE 200809L

#include <signal.h>
#include <stdlib.h>

#include "linux_abi.h"

static void unwanted(void)
{
    _Exit(20);
}

/* Change the TLS guard after GCC saves it, without an out-of-bounds C access. */
__attribute__((stack_protect, noinline))
static void change_guard(void)
{
    __asm__ volatile ("xorq $0x100, %%fs:0x28" ::: "memory", "cc");
}

int main(int argc, char **argv)
{
    if (atexit(unwanted) != 0)
        return 21;
    if (argc == 2 && argv[1][0] == 'm') {
        const struct kernel_sigaction ignore = {SIG_IGN, 0, 0, 0};
        const uint64_t mask = UINT64_C(1) << (SIGABRT - 1);
        if (__al_syscall(__NR_rt_sigaction, SIGABRT, (long)&ignore, 0, sizeof mask, 0, 0) != 0)
            return 22;
        if (__al_syscall(__NR_rt_sigprocmask, SIG_BLOCK, (long)&mask, 0, sizeof mask, 0, 0) != 0)
            return 23;
    }
    change_guard();
    return 24;
}
