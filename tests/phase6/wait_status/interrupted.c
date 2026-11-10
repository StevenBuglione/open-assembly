#include "child.h"

static volatile sig_atomic_t alarm_seen;

struct kernel_timeval { long seconds, microseconds; };
struct kernel_itimer { struct kernel_timeval interval, initial; };

static void alarm_handler(int signal_number)
{
    if (signal_number == SIGALRM)
        alarm_seen = 1;
}

static int set_timer(const struct kernel_itimer *timer)
{
    enum { K_ITIMER_REAL = 0 };
    return kernel_call(__NR_setitimer, K_ITIMER_REAL, (long)timer, 0, 0, 0, 0) == 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    int specific = same_text(argv[1], "waitpid");
    if (!specific && !same_text(argv[1], "wait"))
        return 90;

    struct sigaction action = {0};
    action.sa_handler = alarm_handler;
    sigset_t alarms;
    if (sigemptyset(&action.sa_mask) || sigemptyset(&alarms) ||
        sigaddset(&alarms, SIGALRM) || sigaction(SIGALRM, &action, NULL) ||
        sigprocmask(SIG_UNBLOCK, &alarms, NULL))
        return 91;
    struct child child = {0, -1};
    if (!start_child(&child, 31, 1))
        return 92;

    const struct kernel_itimer repeating = {{0, 20000}, {0, 20000}};
    const struct kernel_itimer stopped = {{0, 0}, {0, 0}};
    int status = 93;
    if (!set_timer(&repeating))
        goto done;
    struct status_box box = boxed(STATUS_SENTINEL);
    errno = TEST_ERRNO;
    pid_t result = specific ? waitpid(child.pid, &box.status, 0) : wait(&box.status);
    int error = errno;
    if (!set_timer(&stopped))
        goto done;
    if (!alarm_seen) {
        status = 94;
        goto done;
    }
    if (result != -1 || error != EINTR) {
        status = 31;
        goto done;
    }
    if (!guarded(&box) || box.status != STATUS_SENTINEL ||
        raw_wait4(child.pid, NULL, WNOHANG) != 0) {
        status = 32;
        goto done;
    }
    int exited = STATUS_SENTINEL;
    if (!release_child(&child) || raw_wait4(child.pid, &exited, 0) != child.pid ||
        exited != (31 << 8)) {
        status = 95;
        goto done;
    }
    status = 0;
done:
    return clean_child(&child) ? status : 96;
}
