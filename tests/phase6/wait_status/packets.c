#include "child.h"

#include <time.h>

struct stimulus { uint64_t mode, value; };
struct result { int32_t pid, status, before, error; };
struct observed {
    struct result steps[3];
    uint64_t scenario, options;
};
_Static_assert(sizeof(struct stimulus) == 16 && sizeof(struct observed) == 64,
               "Linux LP64 wire widths");

enum { K_P_PID = 1, K_WEXITED = 4, K_WNOWAIT = 0x01000000 };
enum { K_CLD_EXITED = 1, K_CLD_STOPPED = 5, K_CLD_CONTINUED = 6 };

static int read_row(struct stimulus *input)
{
    size_t done = 0;
    while (done < sizeof *input) {
        long n = raw_read(STDIN_FILENO, (char *)input + done, sizeof *input - done);
        if (n == -EINTR)
            continue;
        if (n < 0 || (!n && done))
            return -1;
        if (!n)
            return 0;
        done += (size_t)n;
    }
    return 1;
}

static int write_row(const struct observed *output)
{
    size_t done = 0;
    while (done < sizeof *output) {
        long n = raw_write(STDOUT_FILENO, (const char *)output + done, sizeof *output - done);
        if (n == -EINTR)
            continue;
        if (n <= 0)
            return 0;
        done += (size_t)n;
    }
    return 1;
}

static int pending(pid_t child, int options, int code)
{
    struct timespec retry = {0, 1000000};
    for (unsigned attempt = 0; attempt < 1000; ++attempt) {
        siginfo_t info = {0};
        long result = kernel_call(__NR_waitid, K_P_PID, child, (long)&info,
                                  options | K_WNOWAIT | WNOHANG, 0, 0);
        if (result == -EINTR)
            continue;
        if (result)
            return 0;
        if (info.si_pid)
            return info.si_pid == child && info.si_signo == SIGCHLD && info.si_code == code;
        (void)kernel_call(__NR_nanosleep, (long)&retry, 0, 0, 0, 0, 0);
    }
    return 0;
}

struct expectation {
    pid_t pid;
    int status, error;
};

static int observe(int specific, pid_t selector, int options, int null_status, int sentinel,
                   struct expectation want, struct result *output)
{
    struct status_box box = boxed(STATUS_SENTINEL);
    int *destination = null_status ? NULL : &box.status;
    errno = sentinel;
    pid_t result = specific ? waitpid(selector, destination, options) : wait(destination);
    int error = errno;
    if (result != want.pid || error != want.error)
        return 21;
    if (!guarded(&box) || box.status != want.status)
        return 22;
    *output = (struct result){result > 0 ? 1 : result, box.status, sentinel, error};
    return 0;
}

static int empty(int specific, int sentinel, struct result *result)
{
    return observe(specific, -1, specific ? WNOHANG : 0, 0, sentinel,
                   (struct expectation){-1, STATUS_SENTINEL, ECHILD}, result);
}

static int clean_pair(struct child *first, struct child *second)
{
    int clean_first = clean_child(first);
    return clean_child(second) && clean_first;
}

static int wait_row(struct stimulus input, struct observed *output, int sentinel)
{
    unsigned mode = (unsigned)(input.mode % 5);
    output->scenario = mode;
    if (mode == 3)
        return empty(0, sentinel, &output->steps[0]);

    unsigned code = 256 + (unsigned)(input.value & 255);
    unsigned other_code = (code + 97) & 255;
    struct child child = {0, -1}, other = {0, -1};
    int result = 91;
    if ((mode == 4 && !start_child(&other, other_code, 1)) ||
        !start_child(&child, code, mode == 2 || mode == 4))
        goto done;
    int status = (int)(code & 255) << 8;
    if (mode == 2) {
        result = 92;
        if (child_kill(child.pid, SIGKILL) || !release_child(&child))
            goto done;
        status = SIGKILL;
    } else if (mode == 4) {
        result = 92;
        if (kernel_call(__NR_setpgid, child.pid, child.pid, 0, 0, 0, 0) ||
            !release_child(&child))
            goto done;
    }
    if (mode == 1)
        status = STATUS_SENTINEL;
    result = observe(0, -1, 0, mode == 1, sentinel,
                     (struct expectation){child.pid, status, sentinel}, &output->steps[0]);
    if (result)
        goto done;
    if (!reaped(&child)) {
        result = 23;
        goto done;
    }
    unsigned next = 1;
    if (mode == 4) {
        result = 92;
        if (!release_child(&other))
            goto done;
        result = observe(0, -1, 0, 0, sentinel,
                         (struct expectation){other.pid, (int)other_code << 8, sentinel},
                         &output->steps[next++]);
        if (result)
            goto done;
        if (!reaped(&other)) {
            result = 23;
            goto done;
        }
    }
    result = empty(0, sentinel, &output->steps[next]);
done:
    return clean_pair(&child, &other) ? result : 93;
}

static int transition_row(struct child *child, int sentinel, struct observed *output)
{
    if (child_kill(child->pid, SIGSTOP) || !pending(child->pid, WUNTRACED, K_CLD_STOPPED))
        return 92;
    int flags = WUNTRACED | WNOHANG;
    output->options = (unsigned)flags;
    int result = observe(1, child->pid, flags, 0, sentinel,
                         (struct expectation){child->pid, (SIGSTOP << 8) | 0x7f, sentinel},
                         &output->steps[0]);
    if (result)
        return result;
    if (child_kill(child->pid, SIGCONT) || !pending(child->pid, WCONTINUED, K_CLD_CONTINUED))
        return 92;
    return observe(1, child->pid, WCONTINUED | WNOHANG, 0, sentinel,
                   (struct expectation){child->pid, 0xffff, sentinel}, &output->steps[1]);
}

static int waitpid_row(struct stimulus input, struct observed *output, int sentinel)
{
    unsigned mode = (unsigned)(input.mode % 9);
    output->scenario = mode;
    if (mode == 6) {
        output->options = WNOHANG;
        return empty(1, sentinel, &output->steps[0]);
    }

    unsigned code = 256 + (unsigned)(input.value & 255);
    unsigned other_code = (code + 97) & 255;
    unsigned leader_code = (code + 53) & 255;
    struct child child = {0, -1}, other = {0, -1}, leader = {0, -1};
    int result = 91;
    if (mode == 3 && (!start_child(&leader, leader_code, 1) ||
                      kernel_call(__NR_setpgid, leader.pid, leader.pid, 0, 0, 0, 0)))
        goto done;
    if (mode == 2 || mode == 3) {
        if (!start_child(&other, other_code, 1) ||
            (mode == 2 && kernel_call(__NR_setpgid, other.pid, other.pid, 0, 0, 0, 0)) ||
            !release_child(&other) || !pending(other.pid, K_WEXITED, K_CLD_EXITED))
            goto done;
    }
    if (!start_child(&child, code, mode >= 3))
        goto done;
    pid_t selector = child.pid;
    if (mode == 1) {
        selector = -1;
    } else if (mode == 2) {
        selector = 0;
    } else if (mode == 3) {
        if (kernel_call(__NR_setpgid, child.pid, leader.pid, 0, 0, 0, 0))
            goto done;
        selector = -leader.pid;
    }

    unsigned next = 0;
    int status = (int)(code & 255) << 8;
    int null_status = mode == 1 && ((input.value >> 8) & 1);
    if (null_status)
        status = STATUS_SENTINEL;
    if (mode == 4 || mode == 5) {
        int flags = mode == 4 ? WNOHANG : INVALID_WAIT_FLAGS;
        output->options = (unsigned)flags;
        result = observe(1, selector, flags, 0, sentinel,
                         (struct expectation){mode == 4 ? 0 : -1, STATUS_SENTINEL,
                                              mode == 4 ? sentinel : EINVAL},
                         &output->steps[next++]);
        if (result)
            goto done;
    } else if (mode == 7) {
        result = 92;
        if (child_kill(child.pid, SIGKILL))
            goto done;
        status = SIGKILL;
    } else if (mode == 8) {
        result = transition_row(&child, sentinel, output);
        if (result)
            goto done;
        next = 2;
    }
    result = 92;
    if (!release_child(&child))
        goto done;
    result = observe(1, selector, 0, null_status, sentinel,
                     (struct expectation){child.pid, status, sentinel}, &output->steps[next++]);
    if (result)
        goto done;
    if (!reaped(&child)) {
        result = 23;
        goto done;
    }
    if (other.pid) {
        int other_status = STATUS_SENTINEL;
        if (raw_wait4(other.pid, &other_status, WNOHANG) != other.pid ||
            other_status != ((int)other_code << 8)) {
            result = 23;
            goto done;
        }
    }
    if (leader.pid) {
        int leader_status = STATUS_SENTINEL;
        if (!release_child(&leader) || raw_wait4(leader.pid, &leader_status, 0) != leader.pid ||
            leader_status != ((int)leader_code << 8)) {
            result = 92;
            goto done;
        }
    }
    if (next < 3)
        result = empty(1, sentinel, &output->steps[next]);
done:
    int cleaned = clean_pair(&child, &other);
    return clean_child(&leader) && cleaned ? result : 93;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    int specific = same_text(argv[1], "waitpid");
    if (!specific && !same_text(argv[1], "wait"))
        return 90;
    struct stimulus input;
    int received;
    while ((received = read_row(&input)) > 0) {
        struct observed output = {0};
        int sentinel = 700 + (int)((input.value >> 32) & 0x7fff);
        int result = specific ? waitpid_row(input, &output, sentinel)
                              : wait_row(input, &output, sentinel);
        if (result)
            return result;
        if (!write_row(&output))
            return 94;
    }
    return received < 0 ? 95 : 0;
}
