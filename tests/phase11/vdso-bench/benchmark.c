#define _POSIX_C_SOURCE 200809L
#include <asm/unistd.h>
#include <errno.h>
#include <linux/audit.h>
#include <linux/filter.h>
#include <linux/prctl.h>
#include <linux/seccomp.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

static long raw(long number, long first, long second, long third)
{
    register long fourth __asm__("r10") = 0;
    register long fifth __asm__("r8") = 0;
    register long sixth __asm__("r9") = 0;
    __asm__ volatile("syscall" : "+a"(number)
                     : "D"(first), "S"(second), "d"(third), "r"(fourth), "r"(fifth), "r"(sixth)
                     : "rcx", "r11", "memory");
    return number;
}

static int install(void)
{
    struct sock_filter filter[] = {
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, arch)),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, AUDIT_ARCH_X86_64, 1, 0),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_KILL_PROCESS),
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, nr)),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_time, 0, 1),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | EACCES),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_gettimeofday, 0, 1),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | EACCES),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_clock_gettime, 0, 4),
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, args[0])),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, CLOCK_MONOTONIC, 2, 0),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, CLOCK_THREAD_CPUTIME_ID, 1, 0),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | EACCES),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
    };
    struct sock_fprog program = { .len = sizeof filter / sizeof *filter, .filter = filter };
    return raw(__NR_prctl, PR_SET_NO_NEW_PRIVS, 1, 0) == 0 &&
           raw(__NR_seccomp, SECCOMP_SET_MODE_FILTER, 0, (long)&program) == 0;
}

static uint64_t nanoseconds(struct timespec instant)
{
    return (uint64_t)instant.tv_sec * UINT64_C(1000000000) + (uint64_t)instant.tv_nsec;
}

int main(int argc, char **argv)
{
    if (argc != 1 && (argc != 2 || strcmp(argv[1], "qualify")))
        return 1;
    const unsigned count = 1000000;
    struct timespec reference, blocked;
    if (raw(__NR_clock_gettime, CLOCK_REALTIME, (long)&reference, 0) || reference.tv_sec < 0 ||
        reference.tv_sec > INT64_MAX - 10)
        return 2;
    const time_t lower = reference.tv_sec;
    const time_t upper = lower + 10;
    time_t warmed = time(NULL);
    if (warmed < lower || warmed > upper)
        return 3;
    if (!install())
        return 7;
    const int linux_realtime_coarse = 5;
    if (raw(__NR_time, 0, 0, 0) != -EACCES ||
        raw(__NR_gettimeofday, (long)&blocked, 0, 0) != -EACCES ||
        raw(__NR_clock_gettime, CLOCK_REALTIME, (long)&blocked, 0) != -EACCES ||
        raw(__NR_clock_gettime, linux_realtime_coarse, (long)&blocked, 0) != -EACCES)
        return 4;
    warmed = time(NULL);
    if (warmed < lower || warmed > upper)
        return 8;
    if (argc == 2)
        return puts("PASS realtime through vDSO with raw calls denied") < 0 ? 9 : 0;

    struct timespec start, finish, cpu_start, cpu_finish;
    if (clock_gettime(CLOCK_THREAD_CPUTIME_ID, &cpu_start) || clock_gettime(CLOCK_MONOTONIC, &start))
        return 5;
    unsigned valid = 0;
    for (unsigned i = 0; i < count; ++i) {
        time_t seconds = time(NULL);
        valid += seconds >= lower && seconds <= upper;
    }
    if (clock_gettime(CLOCK_MONOTONIC, &finish) || clock_gettime(CLOCK_THREAD_CPUTIME_ID, &cpu_finish) ||
        valid != count)
        return 6;
    printf("%lu %lu %u\n", (unsigned long)(nanoseconds(finish) - nanoseconds(start)),
           (unsigned long)(nanoseconds(cpu_finish) - nanoseconds(cpu_start)), valid);
    return 0;
}
