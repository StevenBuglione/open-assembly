#include <asm/unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/audit.h>
#include <linux/capability.h>
#include <linux/filter.h>
#include <linux/memfd.h>
#include <linux/prctl.h>
#include <linux/seccomp.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

extern long __al_syscall(long, long, long, long, long, long, long);

#define ALLOW(name) \
    BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_##name, 0, 1), \
    BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW)
#define DENY(name, error) \
    BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_##name, 0, 1), \
    BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | (error))

static int install(unsigned remap_errno, unsigned clock_errno)
{
    struct sock_filter instructions[] = {
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, arch)),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, AUDIT_ARCH_X86_64, 1, 0),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_KILL_PROCESS),
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, nr)),
        DENY(mremap, remap_errno),
        DENY(process_vm_readv, EPERM),
        DENY(pwritev2, ENOSYS),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_clock_gettime, 0, 1),
        BPF_STMT(BPF_RET | BPF_K, clock_errno ? SECCOMP_RET_ERRNO | clock_errno : SECCOMP_RET_ALLOW),
        ALLOW(prctl), ALLOW(seccomp), ALLOW(getpid), ALLOW(mmap), ALLOW(munmap), ALLOW(mincore),
        ALLOW(futex), ALLOW(fcntl), ALLOW(fstatfs), ALLOW(pread64), ALLOW(pwrite64),
        ALLOW(write), ALLOW(close), ALLOW(exit), ALLOW(exit_group),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | EACCES),
    };
    struct sock_fprog program = { .len = sizeof instructions / sizeof *instructions, .filter = instructions };
    if (__al_syscall(__NR_seccomp, SECCOMP_SET_MODE_FILTER, 0, (long)&program, 0, 0, 0))
        return 11;
    if (__al_syscall(__NR_prctl, PR_GET_SECCOMP, 0, 0, 0, 0, 0) != SECCOMP_MODE_FILTER ||
        __al_syscall(__NR_prctl, PR_GET_NO_NEW_PRIVS, 0, 0, 0, 0, 0) != 1 ||
        __al_syscall(__NR_getppid, 0, 0, 0, 0, 0, 0) != -EACCES)
        return 12;
    return 0;
}

static int no_privilege(void)
{
    struct __user_cap_header_struct header = { .version = _LINUX_CAPABILITY_VERSION_3 };
    struct __user_cap_data_struct caps[_LINUX_CAPABILITY_U32S_3] = {{0}};
    if (__al_syscall(__NR_capget, (long)&header, (long)caps, 0, 0, 0, 0) ||
        caps[CAP_SYS_ADMIN / 32].effective & (1U << (CAP_SYS_ADMIN % 32)) ||
        __al_syscall(__NR_getppid, 0, 0, 0, 0, 0, 0) <= 0 ||
        __al_syscall(__NR_prctl, PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0, 0))
        return 10;
    return 0;
}

static int realloc_fallback(unsigned denial)
{
    const size_t old_size = 64 * 1024;
    const size_t new_size = 512 * 1024 + 1;
    unsigned char *old = malloc(old_size);
    if (!old)
        return 20;
    for (size_t i = 0; i < old_size; ++i)
        old[i] = (unsigned char)(i * 43U + 13U);
    const uintptr_t old_address = (uintptr_t)old;
    int installed = install(denial, 0);
    if (installed)
        return installed;
    if (__al_syscall(__NR_mremap, 0, 0, 0, 0, 0, 0) != -(long)denial)
        return 21;
    errno = EDOM;
    unsigned char *replacement = realloc(old, new_size);
    if (!replacement || (uintptr_t)replacement == old_address || errno != EDOM)
        return 22;
    for (size_t i = 0; i < old_size; ++i)
        if (replacement[i] != (unsigned char)(i * 43U + 13U))
            return 23;
    replacement[new_size - 1] = 0xa5;
    unsigned char resident = 0;
    if (__al_syscall(__NR_mincore, (long)(old_address & ~(uintptr_t)4095), 4096,
                     (long)&resident, 0, 0, 0) != -ENOMEM)
        return 24;
    free(replacement);
    return 0;
}

static int realtime_fallback(void)
{
    int installed = install(ENOSYS, 0);
    if (installed)
        return installed;
    long pid = __al_syscall(__NR_getpid, 0, 0, 0, 0, 0, 0);
    if (pid <= 0 || __al_syscall(__NR_process_vm_readv, pid, 0, 0, 0, 0, 0) != -EPERM)
        return 30;
    struct timespec reference;
    if (__al_syscall(__NR_clock_gettime, CLOCK_REALTIME, (long)&reference, 0, 0, 0, 0))
        return 31;
    errno = EDOM;
    time_t result = 0;
    const time_t returned = time(&result);
    if (returned != result || result < reference.tv_sec || result > reference.tv_sec + 10 || errno != EDOM)
        return 32;
    installed = install(ENOSYS, EACCES);
    if (installed)
        return installed;
    if (__al_syscall(__NR_clock_gettime, CLOCK_REALTIME, (long)&reference, 0, 0, 0, 0) != -EACCES)
        return 33;
    if (time(&result) != (time_t)-1 || result != returned || errno != EACCES)
        return 34;
    return 0;
}

static int append_failure(void)
{
    long raw = __al_syscall(__NR_memfd_create, (long)"oa-platform", MFD_CLOEXEC, 0, 0, 0, 0);
    if (raw < 0)
        return 40;
    int fd = (int)raw;
    if (write(fd, "abc", 3) != 3 || fcntl(fd, F_SETFL, O_APPEND) < 0)
        return 41;
    int installed = install(ENOSYS, 0);
    if (installed)
        return installed;
    if (__al_syscall(__NR_pwritev2, fd, 0, 0, 0, 0, 0) != -ENOSYS)
        return 42;
    if (pwrite(fd, "X", 1, 0) != -1 || errno != EOPNOTSUPP)
        return 43;
    char bytes[4] = {0};
    if (pread(fd, bytes, sizeof bytes, 0) != 3 || memcmp(bytes, "abc", 3))
        return 44;
    if (fcntl(fd, F_SETFL, 0) < 0 || pwrite(fd, "X", 1, 0) != 1 ||
        pread(fd, bytes, sizeof bytes, 0) != 3 || memcmp(bytes, "Xbc", 3) || close(fd))
        return 45;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 2;
    int status = no_privilege();
    if (status)
        return status;
    const char *result;
    if (!strcmp(argv[1], "remap-enosys")) {
        status = realloc_fallback(ENOSYS);
        result = "PASS seccomp remap ENOSYS preserves and moves allocation\n";
    } else if (!strcmp(argv[1], "remap-eperm")) {
        status = realloc_fallback(EPERM);
        result = "PASS seccomp remap EPERM preserves and moves allocation\n";
    } else if (!strcmp(argv[1], "vdso-eperm")) {
        status = realtime_fallback();
        result = "PASS seccomp vDSO EPERM uses raw clock and publishes EACCES\n";
    } else if (!strcmp(argv[1], "append-enosys")) {
        status = append_failure();
        result = "PASS seccomp pwritev2 ENOSYS leaves append file unchanged\n";
    } else {
        return 3;
    }
    if (status)
        return status;
    const size_t size = strlen(result);
    return write(STDOUT_FILENO, result, size) == (ssize_t)size ? 0 : 4;
}
