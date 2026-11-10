#include "../kernel_abi.h"
#include <signal.h>
#include <stdint.h>

#define OFFSET(type, field, expected) \
    _Static_assert(offsetof(type, field) == (expected), #type "." #field)
_Static_assert(sizeof(sigset_t) == 128 && _Alignof(sigset_t) == 8, "signal mask ABI");
_Static_assert(sizeof(siginfo_t) == 128 && _Alignof(siginfo_t) == 8, "signal information ABI");
_Static_assert(sizeof(struct sigaction) == 152 && _Alignof(struct sigaction) == 8, "sigaction ABI");
OFFSET(siginfo_t, si_signo, 0);
OFFSET(siginfo_t, si_errno, 4);
OFFSET(siginfo_t, si_code, 8);
OFFSET(siginfo_t, si_pid, 16);
OFFSET(siginfo_t, si_uid, 20);
OFFSET(struct sigaction, sa_handler, 0);
OFFSET(struct sigaction, sa_mask, 8);
OFFSET(struct sigaction, sa_flags, 136);

enum { K_SA_RESTORER = 0x04000000 };

struct kernel_action {
    uintptr_t handler;
    uint64_t flags;
    uintptr_t restorer;
    uint64_t mask;
};

_Static_assert(sizeof(struct kernel_action) == 32, "Linux signal action size");
OFFSET(struct kernel_action, handler, 0);
OFFSET(struct kernel_action, flags, 8);
OFFSET(struct kernel_action, restorer, 16);
OFFSET(struct kernel_action, mask, 24);

struct boxed_mask {
    uint64_t before;
    sigset_t mask;
    uint64_t after;
};

static uint64_t signal_bit(int signal_number)
{
    return UINT64_C(1) << (signal_number - 1);
}

static void fill(void *destination, size_t size, unsigned char value)
{
    unsigned char *bytes = destination;
    for (size_t i = 0; i < size; ++i)
        bytes[i] = value;
}

static int all_bytes(const void *storage, size_t size, unsigned char value)
{
    const unsigned char *bytes = storage;
    for (size_t i = 0; i < size; ++i) {
        if (bytes[i] != value)
            return 0;
    }
    return 1;
}

static uint64_t low_mask(const sigset_t *set)
{
    const unsigned char *bytes = (const unsigned char *)set;
    uint64_t low = 0;
    for (unsigned i = 0; i < 8; ++i)
        low |= (uint64_t)bytes[i] << (8 * i);
    return low;
}

static void make_mask(sigset_t *set, uint64_t value)
{
    unsigned char *bytes = (unsigned char *)set;
    fill(set, sizeof *set, 0);
    for (unsigned i = 0; i < 8; ++i)
        bytes[i] = (unsigned char)(value >> (8 * i));
}

static int mask_matches(const sigset_t *set, uint64_t value)
{
    if (low_mask(set) != value)
        return 0;
#ifndef OA_PHASE6_HOST
    if (!all_bytes((const unsigned char *)set + 8, sizeof *set - 8, 0))
        return 0;
#endif
    return 1;
}

static int canaries(const struct boxed_mask *box)
{
    return box->before == UINT64_C(0xa5a5a5a5a5a5a5a5) && box->after == box->before;
}

static long mask_call(int how, const uint64_t *mask, uint64_t *old)
{
    return kernel_call(__NR_rt_sigprocmask, how, (long)mask, (long)old, 8, 0, 0);
}

static long action_call(int number, const struct kernel_action *action, struct kernel_action *old)
{
    return kernel_call(__NR_rt_sigaction, number, (long)action, (long)old, 8, 0, 0);
}

static long send_signal(long pid, int number)
{
    return kernel_call(__NR_kill, pid, number, 0, 0, 0, 0);
}

static long self(void)
{
    return kernel_call(__NR_getpid, 0, 0, 0, 0, 0, 0);
}

static int raw_install(int number, uintptr_t handler, int flags, uint64_t mask)
{
#ifdef OA_PHASE6_HOST
    struct sigaction action = {0};
    if (flags & SA_SIGINFO)
        action.sa_sigaction = (void (*)(int, siginfo_t *, void *))handler;
    else
        action.sa_handler = (void (*)(int))handler;
    action.sa_flags = flags;
    make_mask(&action.sa_mask, mask);
    return sigaction(number, &action, NULL);
#else
    extern void __al_rt_sigreturn(void);
    struct kernel_action action = {
        handler, (unsigned int)flags | K_SA_RESTORER, (uintptr_t)__al_rt_sigreturn, mask
    };
    return (int)action_call(number, &action, NULL);
#endif
}

static volatile sig_atomic_t caught, last, own_mask, another_mask;
static volatile sig_atomic_t number_seen, code_seen, error_seen, pid_seen, uid_seen, context_seen;

static void plain_handler(int number)
{
    uint64_t current = 0;
    if (mask_call(SIG_SETMASK, NULL, &current) == 0) {
        own_mask = !!(current & signal_bit(number));
        another_mask = !!(current & signal_bit(SIGUSR2));
    }
    last = number;
    ++caught;
}

static void info_handler(int number, siginfo_t *info, void *context)
{
    if (info) {
        number_seen = info->si_signo;
        error_seen = info->si_errno;
        code_seen = info->si_code;
        pid_seen = info->si_pid;
        uid_seen = (sig_atomic_t)info->si_uid;
    }
    context_seen = context != NULL;
    plain_handler(number);
}

static int info_matches(int number, int code)
{
    long uid = kernel_call(__NR_getuid, 0, 0, 0, 0, 0, 0);
    return caught == 1 && last == number && number_seen == number && error_seen == 0 &&
           code_seen == code && pid_seen == self() && uid_seen == uid && context_seen;
}

static int empty_case(void)
{
    struct boxed_mask box;
    fill(&box, sizeof box, 0xa5);
    errno = TEST_ERRNO;
    if (sigemptyset(&box.mask) || errno != TEST_ERRNO || !canaries(&box) ||
        !mask_matches(&box.mask, 0))
        return 11;
    return 0;
}

static int fill_case(void)
{
    struct boxed_mask box;
    fill(&box, sizeof box, 0xa5);
    errno = TEST_ERRNO;
    if (sigfillset(&box.mask) || errno != TEST_ERRNO || !canaries(&box))
        return 20;
#ifdef OA_PHASE6_HOST
    const uint64_t live = UINT64_MAX & ~(signal_bit(32) | signal_bit(33) | signal_bit(34));
    if ((low_mask(&box.mask) & live) != live)
        return 21;
#else
    if (!mask_matches(&box.mask, UINT64_MAX))
        return 21;
#endif
    return 0;
}

static int modify_case(int remove)
{
    const int numbers[] = {1, SIGUSR1, SIGUSR2, 31, 64,
#ifndef OA_PHASE6_HOST
                           32, 33, 34,
#endif
    };
    const int invalid[] = {0, -1, 65, 2147483647};
    struct boxed_mask box;
    fill(&box, sizeof box, 0xa5);
    uint64_t current = remove ? UINT64_MAX : 0;
    make_mask(&box.mask, current);
    errno = TEST_ERRNO;
    for (size_t i = 0; i < sizeof numbers / sizeof numbers[0]; ++i) {
        uint64_t bit = signal_bit(numbers[i]);
        int status;
        if (remove) {
            current &= ~bit;
            status = sigdelset(&box.mask, numbers[i]);
        } else {
            current |= bit;
            status = sigaddset(&box.mask, numbers[i]);
        }
        if (status || errno != TEST_ERRNO || !canaries(&box) || !mask_matches(&box.mask, current))
            return remove ? 41 : 31;
    }
    for (size_t i = 0; i < sizeof invalid / sizeof invalid[0]; ++i) {
        int status = remove ? sigdelset(&box.mask, invalid[i]) : sigaddset(&box.mask, invalid[i]);
        if (status != -1 || errno != EINVAL || !mask_matches(&box.mask, current) || !canaries(&box))
            return remove ? 42 : 32;
    }
    return 0;
}

static int member_case(void)
{
    struct boxed_mask box;
    fill(&box, sizeof box, 0xa5);
    uint64_t word = signal_bit(SIGUSR1) | signal_bit(64);
#ifndef OA_PHASE6_HOST
    word |= signal_bit(32);
#endif
    make_mask(&box.mask, word);
    errno = TEST_ERRNO;
    if (sigismember(&box.mask, SIGUSR1) != 1 || sigismember(&box.mask, 64) != 1 ||
        sigismember(&box.mask, SIGUSR2) != 0 || errno != TEST_ERRNO)
        return 51;
#ifndef OA_PHASE6_HOST
    if (sigismember(&box.mask, 32) != 1 || sigismember(&box.mask, 33) != 0)
        return 52;
#endif
#if !defined(OA_PHASE6_HOST) || defined(__GLIBC__)
    if (sigismember(&box.mask, 0) != -1 || errno != EINVAL ||
        sigismember(&box.mask, 65) != -1 || errno != EINVAL)
        return 53;
#endif
    if (!mask_matches(&box.mask, word) || !canaries(&box))
        return 54;
    return 0;
}

static int procmask_case(int invalid)
{
    uint64_t baseline = 0, raw = 0;
    if (mask_call(SIG_SETMASK, NULL, &baseline))
        return 60;
    const uint64_t usr1 = signal_bit(SIGUSR1), usr2 = signal_bit(SIGUSR2);
    sigset_t input;
    struct boxed_mask box;
    fill(&box, sizeof box, 0xa5);
    make_mask(&input, usr1 | signal_bit(SIGKILL) | signal_bit(SIGSTOP));
    errno = TEST_ERRNO;
    if (sigprocmask(SIG_SETMASK, &input, &box.mask) || errno != TEST_ERRNO ||
        !mask_matches(&box.mask, baseline) || !canaries(&box) ||
        mask_call(SIG_SETMASK, NULL, &raw) || raw != usr1)
        return 61;

    make_mask(&input, usr2);
    fill(&box, sizeof box, 0xa5);
    if (sigprocmask(SIG_BLOCK, &input, &box.mask) || !mask_matches(&box.mask, usr1) ||
        mask_call(SIG_SETMASK, NULL, &raw) || raw != (usr1 | usr2))
        return 62;
    if (sigprocmask(SIG_UNBLOCK, &input, NULL) || mask_call(SIG_SETMASK, NULL, &raw) || raw != usr1)
        return 63;
    fill(&box, sizeof box, 0xa5);
    if (invalid && (sigprocmask(42, &input, &box.mask) != -1 || errno != EINVAL ||
        !all_bytes(&box, sizeof box, 0xa5) || mask_call(SIG_SETMASK, NULL, &raw) || raw != usr1))
        return 64;
    errno = TEST_ERRNO;
    int query = SIG_SETMASK;
#ifndef OA_PHASE6_HOST
    if (invalid)
        query = 42;
#endif
    if (sigprocmask(query, NULL, &box.mask) || errno != TEST_ERRNO ||
        !mask_matches(&box.mask, usr1) || !canaries(&box) ||
        mask_call(SIG_SETMASK, &baseline, NULL))
        return 65;
    return 0;
}

static int pending_case(void)
{
    uint64_t wanted = signal_bit(SIGUSR1), empty = 0;
    if (raw_install(SIGUSR1, (uintptr_t)plain_handler, 0, 0) ||
        mask_call(SIG_SETMASK, &wanted, NULL) || send_signal(self(), SIGUSR1) || caught)
        return 70;
    uint64_t raw = 0;
    if (kernel_call(__NR_rt_sigpending, (long)&raw, 8, 0, 0, 0, 0) || !(raw & wanted))
        return 71;
    struct boxed_mask box;
    fill(&box, sizeof box, 0xa5);
    errno = TEST_ERRNO;
    if (sigpending(&box.mask) || errno != TEST_ERRNO ||
        !mask_matches(&box.mask, raw) || !canaries(&box))
        return 72;
    if (mask_call(SIG_SETMASK, &empty, NULL) || caught != 1 || last != SIGUSR1)
        return 73;
    if (kernel_call(__NR_rt_sigpending, (long)&raw, 8, 0, 0, 0, 0) ||
        sigpending(&box.mask) || !mask_matches(&box.mask, raw) || raw & wanted)
        return 74;
    return 0;
}

static int suspend_case(void)
{
    uint64_t wanted = signal_bit(SIGUSR1), observed = 0;
    if (raw_install(SIGUSR1, (uintptr_t)plain_handler, 0, 0) ||
        mask_call(SIG_SETMASK, &wanted, NULL) || send_signal(self(), SIGUSR1) || caught)
        return 80;
    sigset_t temporary;
    make_mask(&temporary, 0);
    errno = TEST_ERRNO;
    if (sigsuspend(&temporary) != -1 || errno != EINTR || caught != 1 || last != SIGUSR1 ||
        mask_call(SIG_SETMASK, NULL, &observed) || observed != wanted)
        return 81;
    return 0;
}

static int action_case(int handler_mask)
{
    uint64_t empty = 0;
    struct kernel_action before, after;
    if (mask_call(SIG_SETMASK, &empty, NULL) || action_call(SIGUSR1, NULL, &before))
        return 90;
    struct sigaction action = {0}, old;
    action.sa_sigaction = info_handler;
    action.sa_flags = SA_SIGINFO | SA_NODEFER;
    uint64_t extra_mask = handler_mask ? signal_bit(SIGUSR2) : 0;
    make_mask(&action.sa_mask, extra_mask);
    fill(&old, sizeof old, 0xa5);
    errno = TEST_ERRNO;
    if (sigaction(SIGUSR1, &action, &old) || errno != TEST_ERRNO ||
        (uintptr_t)old.sa_handler != before.handler || !mask_matches(&old.sa_mask, before.mask))
        return 91;
    if (action_call(SIGUSR1, NULL, &after) || after.handler != (uintptr_t)info_handler ||
        !(after.flags & SA_SIGINFO) || !(after.flags & SA_NODEFER) ||
        after.mask != extra_mask)
        return 92;
#ifndef OA_PHASE6_HOST
    if (!(after.flags & K_SA_RESTORER) || !after.restorer ||
        old.sa_restorer || (old.sa_flags & K_SA_RESTORER) ||
        !all_bytes((const unsigned char *)&old + 140, 4, 0))
        return 93;
#endif
    if (send_signal(self(), SIGUSR1) || !info_matches(SIGUSR1, SI_USER) ||
        own_mask || another_mask != handler_mask)
        return 94;
    fill(&old, sizeof old, 0xa5);
    if (sigaction(SIGKILL, &action, &old) != -1 || errno != EINVAL ||
        !all_bytes(&old, sizeof old, 0xa5))
        return 95;
    errno = TEST_ERRNO;
    if (sigaction(SIGUSR1, NULL, &old) || errno != TEST_ERRNO ||
        old.sa_sigaction != info_handler || !mask_matches(&old.sa_mask, extra_mask))
        return 96;
    return 0;
}

static int send_case(int thread)
{
    uint64_t empty = 0;
    if (mask_call(SIG_SETMASK, &empty, NULL) ||
        raw_install(SIGUSR1, (uintptr_t)info_handler, SA_SIGINFO, 0))
        return 100;
    long pid = self();
    errno = TEST_ERRNO;
    if (thread) {
        if (raise(SIGUSR1) || errno != TEST_ERRNO || !info_matches(SIGUSR1, SI_TKILL))
            return 103;
        if (raise(-1) != -1 || errno != EINVAL)
            return 104;
#ifndef OA_PHASE6_HOST
        if (raise(0) != -1 || errno != EINVAL)
            return 105;
#endif
    } else {
        if (kill((pid_t)pid, 0) || errno != TEST_ERRNO || caught)
            return 101;
        if (kill((pid_t)pid, SIGUSR1) || errno != TEST_ERRNO || !info_matches(SIGUSR1, SI_USER))
            return 102;
        if (kill((pid_t)pid, -1) != -1 || errno != EINVAL)
            return 106;
    }
    return 0;
}

static int signal_case(void)
{
    uint64_t empty = 0;
    if (mask_call(SIG_SETMASK, &empty, NULL) || raw_install(SIGUSR1, (uintptr_t)SIG_DFL, 0, 0))
        return 110;
    errno = TEST_ERRNO;
    if (signal(SIGUSR1, plain_handler) != SIG_DFL || errno != TEST_ERRNO)
        return 111;
    struct kernel_action actual;
    if (action_call(SIGUSR1, NULL, &actual) || actual.handler != (uintptr_t)plain_handler ||
        !(actual.flags & SA_RESTART) || (actual.flags & SA_NODEFER))
        return 112;
    if (send_signal(self(), SIGUSR1) || send_signal(self(), SIGUSR1) ||
        caught != 2 || last != SIGUSR1 || !own_mask)
        return 113;
    if (signal(SIGUSR1, SIG_IGN) != plain_handler || send_signal(self(), SIGUSR1) || caught != 2)
        return 114;
    if (signal(SIGKILL, plain_handler) != SIG_ERR || errno != EINVAL)
        return 115;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    const char *mode = argv[1];
    if (same_text(mode, "sigemptyset")) return empty_case();
    if (same_text(mode, "sigfillset")) return fill_case();
    if (same_text(mode, "sigaddset")) return modify_case(0);
    if (same_text(mode, "sigdelset")) return modify_case(1);
    if (same_text(mode, "sigismember")) return member_case();
    if (same_text(mode, "sigprocmask")) return procmask_case(0);
    if (same_text(mode, "sigprocmask-invalid")) return procmask_case(1);
    if (same_text(mode, "sigpending")) return pending_case();
    if (same_text(mode, "sigsuspend")) return suspend_case();
    if (same_text(mode, "sigaction")) return action_case(0);
    if (same_text(mode, "sigaction-handler-mask")) return action_case(1);
    if (same_text(mode, "kill")) return send_case(0);
    if (same_text(mode, "raise")) return send_case(1);
    if (same_text(mode, "signal")) return signal_case();
    return 2;
}
