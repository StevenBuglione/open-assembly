#ifndef OA_WAIT_STATUS_CHILD_H
#define OA_WAIT_STATUS_CHILD_H

#include "../kernel_abi.h"

#include <linux/prctl.h>
#include <signal.h>
#include <stdint.h>
#include <sys/wait.h>

_Static_assert(sizeof(pid_t) == 4 && (pid_t)-1 < 0, "Linux signed 32-bit pid_t");

struct child {
    pid_t pid;
    int hold;
};

struct status_box {
    uint32_t left;
    int status;
    uint32_t right;
};

enum { STATUS_SENTINEL = 0x23456789, INVALID_WAIT_FLAGS = 0x02000000 };

static inline struct status_box boxed(int status)
{
    return (struct status_box){UINT32_C(0x31415926), status, UINT32_C(0xfedcba98)};
}

static inline int guarded(const struct status_box *box)
{
    return box->left == UINT32_C(0x31415926) && box->right == UINT32_C(0xfedcba98);
}

static inline _Noreturn void child_exit(int status)
{
    (void)kernel_call(__NR_exit_group, status, 0, 0, 0, 0, 0);
    __builtin_trap();
}

static inline long child_kill(pid_t pid, int signal_number)
{
    return kernel_call(__NR_kill, pid, signal_number, 0, 0, 0, 0);
}

static inline long raw_wait4(pid_t pid, int *status, int options)
{
    long result;
    do {
        result = kernel_call(__NR_wait4, pid, (long)status, options, 0, 0, 0);
    } while (result == -EINTR);
    return result;
}

static inline int clean_child(struct child *child);

static inline int ready_fd(int fd)
{
    struct { int fd; short events, revents; } pollfd = {fd, 1, 0};
    return kernel_call(__NR_poll, (long)&pollfd, 1, 1500, 0, 0, 0) == 1;
}

static inline int start_child(struct child *child, unsigned code, int held)
{
    int ends[2] = {-1, -1};
    if (held && kernel_call(__NR_pipe2, (long)ends, O_CLOEXEC, 0, 0, 0, 0))
        return 0;
    int ready[2] = {-1, -1};
    if (held && kernel_call(__NR_pipe2, (long)ready, O_CLOEXEC, 0, 0, 0, 0)) {
        (void)raw_close(ends[0]);
        (void)raw_close(ends[1]);
        return 0;
    }
    long parent = kernel_call(__NR_getpid, 0, 0, 0, 0, 0, 0);
    long pid = kernel_call(__NR_fork, 0, 0, 0, 0, 0, 0);
    if (pid < 0) {
        if (held) {
            (void)raw_close(ends[0]);
            (void)raw_close(ends[1]);
            (void)raw_close(ready[0]);
            (void)raw_close(ready[1]);
        }
        return 0;
    }
    if (!pid) {
        if (kernel_call(__NR_prctl, PR_SET_PDEATHSIG, SIGKILL, 0, 0, 0, 0) ||
            kernel_call(__NR_getppid, 0, 0, 0, 0, 0, 0) != parent)
            child_exit(231);
        (void)raw_close(STDIN_FILENO);
        (void)raw_close(STDOUT_FILENO);
        (void)raw_close(STDERR_FILENO);
        if (held) {
            (void)raw_close(ends[1]);
            (void)raw_close(ready[0]);
            if (raw_write(ready[1], "R", 1) != 1 || raw_close(ready[1]))
                child_exit(232);
            char byte;
            if (!ready_fd(ends[0]) || raw_read(ends[0], &byte, 1) != 0)
                child_exit(232);
            (void)raw_close(ends[0]);
        }
        child_exit((int)code);
    }
    child->pid = (pid_t)pid;
    child->hold = ends[1];
    if (held) {
        (void)raw_close(ends[0]);
        (void)raw_close(ready[1]);
        char byte;
        int initialized = ready_fd(ready[0]) && raw_read(ready[0], &byte, 1) == 1 && byte == 'R';
        int closed = raw_close(ready[0]) == 0;
        if (!initialized || !closed) {
            (void)clean_child(child);
            return 0;
        }
    }
    return 1;
}

static inline int release_child(struct child *child)
{
    int fd = child->hold;
    child->hold = -1;
    return fd < 0 || raw_close(fd) == 0;
}

static inline int reaped(const struct child *child)
{
    return raw_wait4(child->pid, NULL, WNOHANG) == -ECHILD;
}

static inline int clean_child(struct child *child)
{
    int released = release_child(child);
    if (child->pid <= 0)
        return released;
    long result = raw_wait4(child->pid, NULL, WNOHANG);
    if (!result) {
        long killed = child_kill(child->pid, SIGKILL);
        if (killed && killed != -ESRCH)
            return 0;
        result = raw_wait4(child->pid, NULL, 0);
    }
    return released && (result == -ECHILD || result == child->pid);
}

#endif
