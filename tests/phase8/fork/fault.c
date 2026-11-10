#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>

extern pid_t __real__Fork(void);
static int injected, fault_observed, unexpected_mask;
static unsigned count;
static char trace[16];

static int mask_matches(int blocked)
{
    sigset_t current;
    return sigprocmask(SIG_SETMASK, NULL, &current) == 0 &&
           sigismember(&current, SIGUSR1) == 1 &&
           sigismember(&current, SIGUSR2) == blocked;
}

pid_t __wrap__Fork(void)
{
    if (!injected)
        return __real__Fork();
    ++fault_observed;
    if (!mask_matches(1))
        unexpected_mask = 1;
    errno = injected;
    return -1;
}

static void record(char value)
{
    if (count < sizeof trace)
        trace[count++] = mask_matches(0) ? value : '?';
    errno = EDOM;
}

static void prepare_a(void) { record('a'); }
static void prepare_b(void) { record('b'); }
static void parent_a(void) { record('A'); }
static void parent_b(void) { record('B'); }
static void child_a(void) { record('1'); }
static void child_b(void) { record('2'); }

int main(void)
{
    sigset_t mask;
    if (sigemptyset(&mask) || sigaddset(&mask, SIGUSR1) || sigprocmask(SIG_SETMASK, &mask, NULL))
        return 90;
    if (pthread_atfork(prepare_a, parent_a, child_a) || pthread_atfork(prepare_b, parent_b, child_b))
        return 91;
    int errors[] = {EAGAIN, ENOMEM};
    for (size_t i = 0; i < sizeof errors / sizeof *errors; ++i) {
        injected = errors[i];
        count = fault_observed = unexpected_mask = 0;
        errno = 947;
        pid_t result = fork();
        int observed = errno;
        injected = 0;
        if (result != -1 || observed != errors[i] || fault_observed != 1 ||
            unexpected_mask || !mask_matches(0))
            return 11;
        if (count != 4 || memcmp(trace, "baAB", 4))
            return 12;
    }
    return 0;
}
