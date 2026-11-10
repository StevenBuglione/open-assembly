#ifndef TESTS_RUNTIME_LINUX_ABI_H
#define TESTS_RUNTIME_LINUX_ABI_H

#include <asm/unistd.h>
#include <stdint.h>

/* Private runtime boundary and Linux x86-64 syscall numbers. */
long __al_syscall(long number, long a1, long a2, long a3, long a4, long a5, long a6);
long __al_syscall_result(long result);

#define KERNEL_SA_RESTORER 0x04000000UL

struct kernel_sigaction {
    void (*handler)(int);
    unsigned long flags;
    void (*restorer)(void);
    uint64_t mask;
};

void __al_rt_sigreturn(void);

#endif
