#include <asm/unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/memfd.h>
#include <linux/reboot.h>
#include <linux/utsname.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

extern long __al_syscall(long, long, long, long, long, long, long);

static _Thread_local uint64_t thread_value = UINT64_C(0x0fedcba987654321);
static char worker_complete;

static int line(const char *text)
{
    size_t size = strlen(text);
    return write(STDOUT_FILENO, text, size) == (ssize_t)size;
}

static int run_hello(const char *path)
{
    pid_t pid = fork();
    if (pid < 0)
        return 0;
    if (!pid) {
        char *args[] = {(char *)path, NULL};
        char *env[] = {NULL};
        execve(path, args, env);
        _exit(90);
    }
    int status;
    return waitpid(pid, &status, 0) == pid && WIFEXITED(status) && WEXITSTATUS(status) == 0;
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
    if (status) {
        char reason[64];
        if (snprintf(reason, sizeof reason, "FAIL platform guest status=%d\n", status) > 0)
            line(reason);
    }
    /* This PID 1 is the direct-boot guest. QEMU exits at the reboot request. */
    __al_syscall(__NR_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2, LINUX_REBOOT_CMD_RESTART, 0, 0, 0);
    return 27;
}
