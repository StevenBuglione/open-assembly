#include <asm/ioctls.h>
#include <asm/unistd.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/audit.h>
#include <linux/capability.h>
#include <linux/filter.h>
#include <linux/memfd.h>
#include <linux/prctl.h>
#include <linux/seccomp.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/wait.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

extern long __al_syscall(long, long, long, long, long, long, long);

#define ALLOW(name) \
    BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_##name, 0, 1), \
    BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW)
#define DENY(name, error) \
    BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_##name, 0, 1), \
    BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | (error))

static int apply_filter(struct sock_filter *instructions, size_t count)
{
    struct sock_fprog program = { .len = count, .filter = instructions };
    return __al_syscall(__NR_seccomp, SECCOMP_SET_MODE_FILTER, 0, (long)&program, 0, 0, 0) ? 11 : 0;
}

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
        ALLOW(write), ALLOW(close), ALLOW(exit), ALLOW(exit_group), ALLOW(openat), ALLOW(fork),
        ALLOW(wait4), ALLOW(pipe2), ALLOW(rt_sigaction), ALLOW(rt_sigprocmask), ALLOW(poll),
        ALLOW(epoll_wait), ALLOW(ioctl),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | EACCES),
    };
    int status = apply_filter(instructions, sizeof instructions / sizeof *instructions);
    if (status)
        return status;
    if (__al_syscall(__NR_prctl, PR_GET_SECCOMP, 0, 0, 0, 0, 0) != SECCOMP_MODE_FILTER ||
        __al_syscall(__NR_prctl, PR_GET_NO_NEW_PRIVS, 0, 0, 0, 0, 0) != 1 ||
        __al_syscall(__NR_getppid, 0, 0, 0, 0, 0, 0) != -EACCES)
        return 12;
    return 0;
}

static int restrict_call(unsigned syscall_number, unsigned denial, int action_pointer)
{
    int installed = install(ENOSYS, 0);
    if (installed)
        return installed;
    if (action_pointer) {
        /* x86-64 seccomp_data is little endian. Permit null new-action
           pointers for state queries, even if the high pointer word matters. */
        struct sock_filter setter[] = {
            BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, nr)),
            BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, syscall_number, 0, 5),
            BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, args[1]) + 4),
            BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, 0, 0, 2),
            BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, args[1])),
            BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, 0, 1, 0),
            BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | denial),
            BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
        };
        return apply_filter(setter, sizeof setter / sizeof *setter);
    }
    struct sock_filter targeted[] = {
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, nr)),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, syscall_number, 0, 1),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | denial),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
    };
    return apply_filter(targeted, sizeof targeted / sizeof *targeted);
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

static int directory_denied(void)
{
    DIR *ordinary = opendir(".");
    if (!ordinary || closedir(ordinary))
        return 50;
    int installed = restrict_call(__NR_openat, EACCES, 0);
    if (installed)
        return installed;
    if (__al_syscall(__NR_openat, AT_FDCWD, (long)".", O_DIRECTORY, 0, 0, 0) != -EACCES)
        return 51;
    errno = EDOM;
    return !opendir(".") && errno == EACCES ? 0 : 52;
}

static void old_action(int signal_number)
{
    (void)signal_number;
}

static void new_action(int signal_number)
{
    (void)signal_number;
}

static int signal_denied(void)
{
    struct sigaction original = { .sa_handler = old_action };
    if (sigemptyset(&original.sa_mask) || sigaddset(&original.sa_mask, SIGUSR2) ||
        sigaction(SIGUSR1, &original, NULL))
        return 60;
    int installed = restrict_call(__NR_rt_sigaction, EPERM, 1);
    if (installed)
        return installed;
    struct sigaction changed = { .sa_handler = new_action };
    if (__al_syscall(__NR_rt_sigaction, SIGUSR1, (long)&changed, 0, 8, 0, 0) != -EPERM)
        return 61;
    struct sigaction output;
    unsigned char before[sizeof output];
    memset(&output, 0x6b, sizeof output);
    memcpy(before, &output, sizeof output);
    errno = EDOM;
    if (sigaction(SIGUSR1, &changed, &output) != -1 || errno != EPERM ||
        memcmp(before, &output, sizeof output))
        return 62;
    if (sigaction(SIGUSR1, NULL, &output) || output.sa_handler != old_action ||
        sigismember(&output.sa_mask, SIGUSR2) != 1)
        return 63;
    return 0;
}

static int spawn_denied(char *program)
{
    int installed = restrict_call(__NR_fork, EPERM, 0);
    if (installed)
        return installed;
    long raw = __al_syscall(__NR_fork, 0, 0, 0, 0, 0, 0);
    if (!raw)
        _exit(70);
    if (raw != -EPERM)
        return 70;
    pid_t pid = -719;
    char *args[] = {program, NULL};
    char *env[] = {NULL};
    errno = EDOM;
    if (posix_spawn(&pid, program, NULL, NULL, args, env) != EPERM || pid != -719 || errno != EDOM)
        return 71;
    if (waitpid(-1, NULL, WNOHANG) != -1 || errno != ECHILD)
        return 72;
    return 0;
}

static int readiness_denied(void)
{
    int ends[2];
    int epfd = epoll_create1(EPOLL_CLOEXEC);
    if (epfd < 0 || pipe(ends))
        return 80;
    struct epoll_event event = { .events = EPOLLIN, .data.u64 = 0x456789abcdef1234 };
    if (epoll_ctl(epfd, EPOLL_CTL_ADD, ends[0], &event) || write(ends[1], "R", 1) != 1)
        return 81;
    int installed = restrict_call(__NR_epoll_wait, EPERM, 0);
    if (installed)
        return installed;
    if (__al_syscall(__NR_epoll_wait, epfd, (long)&event, 1, 0, 0, 0) != -EPERM)
        return 82;
    unsigned char before[sizeof event];
    memcpy(before, &event, sizeof event);
    errno = EDOM;
    if (epoll_wait(epfd, &event, 1, 0) != -1 || errno != EPERM || memcmp(before, &event, sizeof event))
        return 83;
    struct pollfd pollfd = { .fd = ends[0], .events = POLLIN };
    if (poll(&pollfd, 1, 0) != 1 || pollfd.revents != POLLIN)
        return 84;
    return close(epfd) || close(ends[0]) || close(ends[1]) ? 85 : 0;
}

static int terminal_denied(void)
{
    const int fd = open("/dev/ptmx", O_RDWR | O_NOCTTY | O_CLOEXEC);
    struct termios settings;
    if (fd < 0 || tcgetattr(fd, &settings))
        return 90;
    int installed = restrict_call(__NR_ioctl, EPERM, 0);
    if (installed)
        return installed;
    if (__al_syscall(__NR_ioctl, fd, TCGETS, (long)&settings, 0, 0, 0) != -EPERM)
        return 91;
    unsigned char before[sizeof settings];
    memset(&settings, 0x95, sizeof settings);
    memcpy(before, &settings, sizeof settings);
    errno = EDOM;
    if (tcgetattr(fd, &settings) != -1 || errno != EPERM || memcmp(before, &settings, sizeof settings))
        return 92;
    return close(fd) ? 93 : 0;
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
    } else if (!strcmp(argv[1], "directory-eacces")) {
        status = directory_denied();
        result = "PASS seccomp openat EACCES rejects directory open\n";
    } else if (!strcmp(argv[1], "signal-eperm")) {
        status = signal_denied();
        result = "PASS seccomp rt_sigaction EPERM preserves disposition and output\n";
    } else if (!strcmp(argv[1], "spawn-eperm")) {
        status = spawn_denied(argv[0]);
        result = "PASS seccomp fork EPERM preserves spawn pid output and creates no child\n";
    } else if (!strcmp(argv[1], "readiness-eperm")) {
        status = readiness_denied();
        result = "PASS seccomp epoll_wait EPERM preserves output and poll readiness\n";
    } else if (!strcmp(argv[1], "terminal-eperm")) {
        status = terminal_denied();
        result = "PASS seccomp ioctl EPERM preserves terminal output\n";
    } else {
        return 3;
    }
    if (status)
        return status;
    const size_t size = strlen(result);
    return write(STDOUT_FILENO, result, size) == (ssize_t)size ? 0 : 4;
}
