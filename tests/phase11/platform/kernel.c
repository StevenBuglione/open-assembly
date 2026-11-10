#include <asm/unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/if.h>
#include <linux/memfd.h>
#include <linux/mount.h>
#include <linux/reboot.h>
#include <linux/sockios.h>
#include <linux/utsname.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

extern long __al_syscall(long, long, long, long, long, long, long);

struct platform_case {
    const char *name;
    char *const *args;
    char *const *env;
};
#include "platform-cases.h"

static _Thread_local uint64_t thread_value = UINT64_C(0x0fedcba987654321);
static char worker_complete;

static int line(const char *text)
{
    size_t size = strlen(text);
    return write(STDOUT_FILENO, text, size) == (ssize_t)size;
}

static int child_status(char *const args[], char *const env[], const char *directory)
{
    pid_t pid = fork();
    if (pid < 0)
        return -1;
    if (!pid) {
        if (directory && __al_syscall(__NR_chdir, (long)directory, 0, 0, 0, 0, 0))
            _exit(89);
        execve(args[0], args, env);
        _exit(90);
    }
    int status;
    return waitpid(pid, &status, 0) == pid ? status : -1;
}

static int run_hello(const char *path)
{
    char *args[] = {(char *)path, NULL};
    char *env[] = {NULL};
    return child_status(args, env, NULL) == 0;
}

static int guest_devices(void)
{
    const long fd = __al_syscall(__NR_socket, AF_INET, SOCK_DGRAM, 0, 0, 0, 0);
    if (fd < 0)
        return 0;
    struct ifreq interface = {.ifr_name = "lo"};
    if (__al_syscall(__NR_ioctl, fd, SIOCGIFFLAGS, (long)&interface, 0, 0, 0))
        return 0;
    interface.ifr_flags |= IFF_UP;
    if (__al_syscall(__NR_ioctl, fd, SIOCSIFFLAGS, (long)&interface, 0, 0, 0) || close((int)fd))
        return 0;
    return __al_syscall(__NR_mount, (long)"devpts", (long)"/dev/pts", (long)"devpts",
                        MS_NOSUID | MS_NOEXEC, (long)"mode=0620,ptmxmode=0666", 0) == 0;
}

static int guest_cases(void)
{
    if (!guest_devices())
        return 61;
    for (size_t i = 0; i < sizeof platform_cases / sizeof *platform_cases; ++i) {
        const struct platform_case *probe = &platform_cases[i];
        char directory[96], message[112];
        int length = snprintf(directory, sizeof directory, "/cases/%s", probe->name);
        if (length < 0 || length >= (int)sizeof directory || mkdir(directory, 0700))
            return 62;
        length = snprintf(message, sizeof message, "BEGIN platform case %s\n", probe->name);
        if (length < 0 || length >= (int)sizeof message || !line(message))
            return 63;
        const int status = child_status(probe->args, probe->env, directory);
        if (status != 0) {
            if (snprintf(message, sizeof message, "FAIL platform case %s wait-status=%d\n", probe->name, status) > 0)
                line(message);
            return 64;
        }
        length = snprintf(message, sizeof message, "END platform case %s\n", probe->name);
        if (length < 0 || length >= (int)sizeof message || !line(message))
            return 65;
    }
    return 0;
}

static void *worker(void *argument)
{
    if (thread_value != UINT64_C(0x0fedcba987654321) || errno != 0)
        return NULL;
    thread_value = UINT64_C(0xcafefeeddeadc0de);
    errno = ERANGE;
    return argument;
}

static int threads(void)
{
    pthread_t thread;
    thread_value = UINT64_C(0x8899aabbccddeeff);
    errno = EDOM;
    if (pthread_create(&thread, NULL, worker, &worker_complete))
        return 0;
    void *result;
    return pthread_join(thread, &result) == 0 && result == &worker_complete &&
           thread_value == UINT64_C(0x8899aabbccddeeff) && errno == EDOM;
}

static int runtime_services(void)
{
    struct timespec monotonic;
    if (clock_gettime(CLOCK_MONOTONIC, &monotonic) || monotonic.tv_sec < 0 ||
        monotonic.tv_nsec < 0 || monotonic.tv_nsec >= 1000000000)
        return 0;
    const size_t length = 65536;
    unsigned char *before = malloc(length);
    if (!before)
        return 0;
    for (size_t i = 0; i < length; ++i)
        before[i] = (unsigned char)(i * 37 + 11);
    unsigned char *after = realloc(before, length * 8);
    if (!after)
        return 0;
    for (size_t i = 0; i < length; ++i)
        if (after[i] != (unsigned char)(i * 37 + 11))
            return 0;
    after[length * 8 - 1] = 0xa5;
    free(after);
    return 1;
}

static int append_check(int guest)
{
    long raw = __al_syscall(__NR_memfd_create, (long)"oa-old-kernel", MFD_CLOEXEC, 0, 0, 0, 0);
    if (raw < 0)
        return 0;
    int fd = (int)raw;
    if (write(fd, "abc", 3) != 3 || fcntl(fd, F_SETFL, O_APPEND) < 0)
        return 0;
    if (guest) {
        struct { const void *base; size_t length; } vector = {"Y", 1};
        const long denied = __al_syscall(__NR_pwritev2, fd, (long)&vector, 1, 0, 0, 32);
        if (denied != -EOPNOTSUPP)
            return 0;
    }
    errno = EDOM;
    const ssize_t result = pwrite(fd, "X", 1, 0);
    char content[4] = {0};
    if (pread(fd, content, sizeof content, 0) != 3 || close(fd))
        return 0;
    if (result == 1 && !guest && !memcmp(content, "Xbc", 3))
        return line("PASS platform append-offset\n");
    if (result == -1 && errno == EOPNOTSUPP && !memcmp(content, "abc", 3))
        return line("PASS platform append-unsupported\n");
    return 0;
}

static int exercise(int guest, const char *asm_hello, const char *c_hello)
{
    struct new_utsname identity;
    if (__al_syscall(__NR_uname, (long)&identity, 0, 0, 0, 0, 0) ||
        strcmp(identity.sysname, "Linux") || strcmp(identity.machine, "x86_64") ||
        (guest && strcmp(identity.release, "4.19.0-27-amd64")))
        return 20;
    long clone3 = __al_syscall(__NR_clone3, 0, 0, 0, 0, 0, 0);
    char release[144];
    int length = snprintf(release, sizeof release, "PLATFORM linux %s x86_64 clone3=%ld\n", identity.release, clone3);
    if (length < 0 || length >= (int)sizeof release || !line(release) || (guest && clone3 != -ENOSYS))
        return 21;
    if (!run_hello(asm_hello) || !run_hello(c_hello) || !line("PASS platform startup-c-and-asm\n"))
        return 22;
    if (!threads() || !line("PASS platform tls-thread-clone\n"))
        return 23;
    if (!runtime_services() || !line("PASS platform clock-and-allocation\n"))
        return 24;
    if (!append_check(guest))
        return 25;
    return line("PASS platform complete\n") ? 0 : 26;
}

int main(int argc, char **argv)
{
    if (argc == 3)
        return exercise(0, argv[1], argv[2]);
    if (argc != 1 || getpid() != 1 || strcmp(argv[0], "/init"))
        return 2;
    int status = exercise(1, "/hello-asm", "/hello-c");
    if (!status)
        status = guest_cases();
    if (status) {
        char reason[64];
        if (snprintf(reason, sizeof reason, "FAIL platform guest status=%d\n", status) > 0)
            line(reason);
    }
    /* This PID 1 is the direct-boot guest. QEMU exits at the reboot request. */
    __al_syscall(__NR_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2, LINUX_REBOOT_CMD_RESTART, 0, 0, 0);
    return 27;
}
