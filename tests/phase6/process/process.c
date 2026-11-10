#include "../kernel_abi.h"
#include <sys/wait.h>

_Static_assert(sizeof(pid_t) == 4 && (pid_t)-1 < 0, "signed 32-bit pid_t");

static long raw_pid(void)
{
    return kernel_call(__NR_getpid, 0, 0, 0, 0, 0, 0);
}

static long raw_ppid(void)
{
    return kernel_call(__NR_getppid, 0, 0, 0, 0, 0, 0);
}

static long raw_fork(void)
{
    return kernel_call(__NR_fork, 0, 0, 0, 0, 0, 0);
}

static long raw_wait(int child, int *status)
{
    long result;
    do {
        result = kernel_call(__NR_wait4, child, (long)status, 0, 0, 0, 0);
    } while (result == -EINTR);
    return result;
}

static _Noreturn void child_exit(int status)
{
    kernel_call(__NR_exit_group, status, 0, 0, 0, 0, 0);
    __builtin_trap();
}

static int getpid_case(void)
{
    long expected = raw_pid();
    if (expected <= 0)
        return 10;
    errno = TEST_ERRNO;
    return getpid() != expected || errno != TEST_ERRNO ? 11 : 0;
}

static int getppid_case(void)
{
    long expected = raw_ppid();
    if (expected <= 0)
        return 20;
    errno = TEST_ERRNO;
    return getppid() != expected || errno != TEST_ERRNO ? 21 : 0;
}

static int fork_case(void)
{
    int fds[2];
    if (kernel_call(__NR_pipe2, (long)fds, 0, 0, 0, 0, 0))
        return 30;
    long parent = raw_pid();
    volatile int local = 0x6162;
    errno = TEST_ERRNO;
    pid_t child = fork();
    if (child < 0 || errno != TEST_ERRNO)
        return 31;
    if (child == 0) {
        long identity[3] = {raw_pid(), raw_ppid(), local};
        if (identity[0] == parent)
            return 32;
        if (identity[1] != parent || raw_close(fds[0]))
            child_exit(90);
        local = 0x6364;
        errno = EINVAL;
        if (raw_write(fds[1], identity, sizeof identity) != sizeof identity || raw_close(fds[1]))
            child_exit(91);
        child_exit(43);
    }

    if (raw_close(fds[1]))
        return 33;
    long identity[3];
    if (raw_read(fds[0], identity, sizeof identity) != sizeof identity ||
        identity[0] != child || identity[1] != parent || identity[2] != local || raw_close(fds[0]))
        return 34;
    int status = -1;
    if (raw_wait(child, &status) != child || status != (43 << 8) ||
        local != 0x6162 || errno != TEST_ERRNO)
        return 35;
    return 0;
}

static int pipe2_case(void)
{
    int slots[4] = {0x12345678, -101, -102, 0x23456789};
    errno = TEST_ERRNO;
    if (pipe2(&slots[1], O_CLOEXEC | O_NONBLOCK) || errno != TEST_ERRNO ||
        slots[0] != 0x12345678 || slots[3] != 0x23456789 ||
        slots[1] < 0 || slots[2] < 0 || slots[1] == slots[2])
        return 41;
    int read_end = slots[1], write_end = slots[2];
    if (raw_fcntl(read_end, K_F_GETFD, 0) != K_FD_CLOEXEC ||
        raw_fcntl(write_end, K_F_GETFD, 0) != K_FD_CLOEXEC ||
        (raw_fcntl(read_end, K_F_GETFL, 0) & (O_ACCMODE | O_NONBLOCK)) != O_NONBLOCK ||
        (raw_fcntl(write_end, K_F_GETFL, 0) & (O_ACCMODE | O_NONBLOCK)) != (O_NONBLOCK | O_WRONLY))
        return 42;
    char byte = 0;
    if (raw_read(read_end, &byte, 1) != -EAGAIN ||
        raw_write(write_end, "P", 1) != 1 || raw_read(read_end, &byte, 1) != 1 || byte != 'P' ||
        raw_close(write_end) || raw_read(read_end, &byte, 1) || raw_close(read_end))
        return 43;
    slots[1] = -101;
    slots[2] = -102;
    if (pipe2(&slots[1], O_DIRECTORY) != -1 || errno != EINVAL ||
        slots[0] != 0x12345678 || slots[1] != -101 ||
        slots[2] != -102 || slots[3] != 0x23456789)
        return 44;
    return 0;
}

static long blocked_child(int ends[2])
{
    if (kernel_call(__NR_pipe2, (long)ends, 0, 0, 0, 0, 0))
        return -1;
    long child = raw_fork();
    if (!child) {
        char byte = 0;
        if (raw_close(ends[1]) || raw_read(ends[0], &byte, 1) != 1 || byte != 'R')
            child_exit(92);
        child_exit(37);
    }
    if (child > 0 && raw_close(ends[0]))
        return -1;
    return child;
}

static int waitpid_case(void)
{
    int ends[2];
    long child = blocked_child(ends);
    if (child < 0)
        return 50;
    int status = 0x12345678;
    errno = TEST_ERRNO;
    if (waitpid((pid_t)child, &status, WNOHANG) != 0 || errno != TEST_ERRNO ||
        status != 0x12345678)
        return 51;
    if (waitpid((pid_t)child, &status, 0x02000000) != -1 || errno != EINVAL ||
        status != 0x12345678)
        return 52;
    if (raw_write(ends[1], "R", 1) != 1 || raw_close(ends[1]))
        return 53;
    errno = TEST_ERRNO;
    if (waitpid((pid_t)child, &status, 0) != child || errno != TEST_ERRNO ||
        status != (37 << 8) || !WIFEXITED(status) || WEXITSTATUS(status) != 37 ||
        WIFSIGNALED(status))
        return 54;

    child = blocked_child(ends);
    enum { kill_signal = 9 };
    if (child < 0 || kernel_call(__NR_kill, child, kill_signal, 0, 0, 0, 0) || raw_close(ends[1]))
        return 55;
    errno = TEST_ERRNO;
    if (waitpid((pid_t)child, &status, 0) != child || errno != TEST_ERRNO ||
        status != kill_signal || !WIFSIGNALED(status) || WTERMSIG(status) != kill_signal ||
        WIFEXITED(status))
        return 56;
    status = 0x23456789;
    if (waitpid(-1, &status, WNOHANG) != -1 || errno != ECHILD || status != 0x23456789)
        return 57;
    return 0;
}

static int wait_case(void)
{
    long child = raw_fork();
    if (child < 0)
        return 60;
    if (!child)
        child_exit(61);
    int status = -1;
    errno = TEST_ERRNO;
    if (wait(&status) != child || errno != TEST_ERRNO || status != (61 << 8) ||
        !WIFEXITED(status) || WEXITSTATUS(status) != 61)
        return 62;
    child = raw_fork();
    if (child < 0)
        return 63;
    if (!child)
        child_exit(62);
    if (wait(NULL) != child || errno != TEST_ERRNO)
        return 64;
    status = 0x23456789;
    if (wait(&status) != -1 || errno != ECHILD || status != 0x23456789)
        return 65;
    return 0;
}

static int exec_failure(void)
{
    int fd = (int)raw_open(AT_FDCWD, "plain", O_RDWR | O_CREAT | O_EXCL, 0700);
    if (fd < 0 || raw_write(fd, "plain text\n", 11) != 11 || raw_close(fd))
        return 81;
    fd = (int)raw_open(AT_FDCWD, "plain", O_RDONLY, 0);
    if (fd < 0)
        return 81;
    char zero[] = "replacement-name", value[] = "PROBE=private";
    char *args[] = {zero, NULL};
    char *env[] = {value, NULL};
    long pid = raw_pid();
    errno = TEST_ERRNO;
    if (execve("missing", args, env) != -1 || errno != ENOENT)
        return 82;
    long reference = kernel_call(__NR_execve, (long)"plain", (long)args, (long)env, 0, 0, 0);
    /* The kernel can reject a text file or the test filesystem's execution policy. */
    if (reference != -ENOEXEC && reference != -EACCES)
        return 83;
    errno = TEST_ERRNO;
    if (execve("plain", args, env) != -1 || errno != -reference)
        return 84;
    char byte = 0;
    if (raw_pid() != pid || args[0] != zero || args[1] || env[0] != value || env[1] ||
        !same_text(zero, "replacement-name") || !same_text(value, "PROBE=private") ||
        raw_seek(fd, 0, SEEK_CUR) || raw_read(fd, &byte, 1) != 1 || byte != 'p')
        return 85;
    return raw_close(fd) || raw_unlink("plain", 0) ? 86 : 0;
}

static void fd_text(char *text, int fd)
{
    char reverse[16];
    unsigned size = 0;
    do {
        reverse[size++] = (char)('0' + fd % 10);
        fd /= 10;
    } while (fd);
    unsigned index = 0;
    while (size)
        text[index++] = reverse[--size];
    text[index] = '\0';
}

static int fd_from_text(const char *text)
{
    int fd = 0;
    if (!*text)
        return -1;
    while (*text) {
        int digit = *text++ - '0';
        if (digit < 0 || digit > 9 || fd > (2147483647 - digit) / 10)
            return -1;
        fd = fd * 10 + digit;
    }
    return fd;
}

static int exec_success(const char *path)
{
    int closed = (int)raw_open(AT_FDCWD, "/dev/null", O_RDONLY | O_CLOEXEC, 0);
    int keep = (int)kernel_call(__NR_memfd_create, (long)"phase6-exec", 0, 0, 0, 0, 0);
    if (closed < 3 || keep < 3 || raw_write(keep, "K", 1) != 1 || raw_seek(keep, 0, SEEK_SET))
        return 90;
    char closed_text[16], keep_text[16];
    fd_text(closed_text, closed);
    fd_text(keep_text, keep);
    char zero[] = "phase6-replaced", mode[] = "exec-child", token[] = "explicit-argument";
    char only[] = "ONLY=explicit", empty[] = "EMPTY=";
    char *args[] = {zero, mode, closed_text, keep_text, token, NULL};
    char *env[] = {only, empty, NULL};
    execve(path, args, env);
    return 91;
}

static int exec_child(int argc, char **argv, char **envp)
{
    if (argc != 5 || argv[5] || !same_text(argv[0], "phase6-replaced") ||
        !same_text(argv[1], "exec-child") || !same_text(argv[4], "explicit-argument"))
        return 92;
    if (!envp[0] || !envp[1] || envp[2] ||
        !same_text(envp[0], "ONLY=explicit") || !same_text(envp[1], "EMPTY="))
        return 93;
    int closed = fd_from_text(argv[2]), keep = fd_from_text(argv[3]);
    char marker = 0;
    if (closed < 3 || keep < 3 || closed == keep || raw_fcntl(closed, K_F_GETFD, 0) != -EBADF ||
        raw_fcntl(keep, K_F_GETFD, 0) != 0 || raw_read(keep, &marker, 1) != 1 ||
        marker != 'K' || raw_close(keep))
        return 94;
    return raw_write(STDOUT_FILENO, "replaced\n", 9) == 9 ? 0 : 95;
}

int main(int argc, char **argv, char **envp)
{
    if (argc >= 2 && same_text(argv[1], "exec-child"))
        return exec_child(argc, argv, envp);
    if (argc != 2)
        return 1;
    const char *mode = argv[1];
    if (same_text(mode, "getpid")) return getpid_case();
    if (same_text(mode, "getppid")) return getppid_case();
    if (same_text(mode, "fork")) return fork_case();
    if (same_text(mode, "pipe2")) return pipe2_case();
    if (same_text(mode, "waitpid")) return waitpid_case();
    if (same_text(mode, "wait")) return wait_case();
    if (same_text(mode, "exec-failure")) return exec_failure();
    if (same_text(mode, "exec-success")) return exec_success(argv[0]);
    return 2;
}
