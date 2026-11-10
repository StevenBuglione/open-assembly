#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

enum { START_VALUE = 0x13579, THREADS = 4, DOWNWARD = 1, UPWARD = 2 };

_Alignas(64) static _Thread_local int local_initialized = START_VALUE;
_Alignas(256) static _Thread_local uint64_t local_zero;

struct job {
    int ready, release, error, index;
    pthread_t handle;
    uintptr_t initialized, zero, errno_slot;
};

static int token;
static pthread_t initial;

static int signal_mask(int how, const sigset_t *set, sigset_t *old)
{
#ifdef OA_PHASE8_HOST
    return pthread_sigmask(how, set, old);
#else
    return sigprocmask(how, set, old);
#endif
}

static unsigned rounding(void)
{
    unsigned short control;
    unsigned int mxcsr;
    __asm__ volatile("fnstcw %0; stmxcsr %1" : "=m"(control), "=m"(mxcsr));
    unsigned x87 = (control >> 10) & 3u;
    unsigned sse = (mxcsr >> 13) & 3u;
    return x87 == sse ? x87 : 4;
}

static void set_rounding(unsigned mode)
{
    unsigned short control;
    unsigned int mxcsr;
    __asm__ volatile("fnstcw %0; stmxcsr %1" : "=m"(control), "=m"(mxcsr));
    control = (unsigned short)((control & ~0x0c00u) | (mode << 10));
    mxcsr = (mxcsr & ~0x6000u) | (mode << 13);
    __asm__ volatile("fldcw %0; ldmxcsr %1" : : "m"(control), "m"(mxcsr));
}

static int wait_flag(const int *flag)
{
    int old_errno = errno;
    const struct timespec pause = {.tv_nsec = 1000000};
    int seen = 0;
    for (unsigned retry = 0; retry < 2000; ++retry) {
        if (__atomic_load_n(flag, __ATOMIC_ACQUIRE)) {
            seen = 1;
            break;
        }
        (void)nanosleep(&pause, NULL);
    }
    errno = old_errno;
    return seen;
}

static void release_flag(int *flag)
{
    __atomic_store_n(flag, 1, __ATOMIC_RELEASE);
}

#ifndef OA_PHASE8_HOST
static uintptr_t guards[2];

static int thread_guard(uintptr_t *stack_guard, uintptr_t *pointer_guard, int *errno_slot)
{
    uintptr_t base;
    __asm__ volatile("movq %%fs:0, %0; movq %%fs:0x28, %1; movq %%fs:0x30, %2"
                     : "=r"(base), "=r"(*stack_guard), "=r"(*pointer_guard));
    return (uintptr_t)errno_slot == base + 0x40;
}
#endif

void *lifecycle_body(void *opaque)
{
    struct job *job = opaque;
    if (!job)
        return NULL;
    job->initialized = (uintptr_t)&local_initialized;
    job->zero = (uintptr_t)&local_zero;
    job->errno_slot = (uintptr_t)&errno;
    job->handle = pthread_self();
    if ((job->initialized & 63u) || (job->zero & 255u) ||
        local_initialized != START_VALUE || local_zero)
        job->error = 1;
#ifndef OA_PHASE8_HOST
    uintptr_t stack_guard, pointer_guard;
    if (errno != 0 || !thread_guard(&stack_guard, &pointer_guard, &errno) ||
        stack_guard != guards[0] || pointer_guard != guards[1])
        job->error = 2;
#endif
    sigset_t blocked;
    if (signal_mask(SIG_SETMASK, NULL, &blocked) || sigismember(&blocked, SIGUSR1) != 1 ||
        sigismember(&blocked, SIGUSR2) != 0 || rounding() != DOWNWARD)
        job->error = 3;
    errno = 100 + job->index;
    local_initialized = 200 + job->index;
    local_zero = 300 + (unsigned)job->index;
    set_rounding(UPWARD);
    release_flag(&job->ready);
    if (!wait_flag(&job->release))
        job->error = 4;
    if (errno != 100 + job->index || local_initialized != 200 + job->index ||
        local_zero != 300 + (unsigned)job->index || rounding() != UPWARD)
        job->error = 5;
    return job;
}

/* Probe the SysV entry before a compiler-generated prologue touches RSP. */
__attribute__((naked))
static void *aligned_entry(void *opaque __attribute__((unused)))
{
    __asm__("mov %rsp, %rax\n\t"
            "and $15, %eax\n\t"
            "cmp $8, %eax\n\t"
            "jne 1f\n\t"
            "pushfq\n\t"
            "pop %rax\n\t"
            "test $0x400, %eax\n\t"
            "jz lifecycle_body\n"
            "1:\n\t"
            "xor %eax, %eax\n\t"
            "ret");
}

static int tls_workers(void)
{
    struct job jobs[THREADS] = {{0}};
    pthread_t handles[THREADS];
    sigset_t block, unblock, original;
    if (sigemptyset(&block) || sigemptyset(&unblock) || sigaddset(&block, SIGUSR1) ||
        sigaddset(&unblock, SIGUSR2) || signal_mask(SIG_BLOCK, &block, &original) ||
        signal_mask(SIG_UNBLOCK, &unblock, NULL))
        return 10;
    unsigned original_rounding = rounding();
    if (original_rounding > 3)
        return 11;
    set_rounding(DOWNWARD);
    local_initialized = -7;
    local_zero = 0x789;
    initial = pthread_self();
#ifndef OA_PHASE8_HOST
    if (!thread_guard(&guards[0], &guards[1], &errno))
        return 12;
#endif
    for (int i = 0; i < THREADS; ++i) {
        jobs[i].index = i;
        errno = EDOM;
        if (pthread_create(&handles[i], NULL, aligned_entry, &jobs[i]) || errno != EDOM)
            return 13;
    }
    for (int i = 0; i < THREADS; ++i) {
        if (!wait_flag(&jobs[i].ready))
            return 14;
        if (!pthread_equal(handles[i], jobs[i].handle) || pthread_equal(initial, jobs[i].handle) ||
            jobs[i].initialized == (uintptr_t)&local_initialized || jobs[i].zero == (uintptr_t)&local_zero ||
            jobs[i].errno_slot == (uintptr_t)&errno)
            return 15;
        for (int j = 0; j < i; ++j) {
            if (pthread_equal(handles[i], handles[j]) || jobs[i].initialized == jobs[j].initialized ||
                jobs[i].zero == jobs[j].zero || jobs[i].errno_slot == jobs[j].errno_slot)
                return 16;
        }
    }
    if (errno != EDOM || local_initialized != -7 || local_zero != 0x789 || rounding() != DOWNWARD)
        return 17;
    for (int i = 0; i < THREADS; ++i)
        release_flag(&jobs[i].release);
    for (int i = THREADS; i-- > 0;) {
        void *result = NULL;
        if (pthread_join(handles[i], &result) || errno != EDOM || result != &jobs[i] || jobs[i].error)
            return 18;
    }
    set_rounding(original_rounding);
    return signal_mask(SIG_SETMASK, &original, NULL) ? 19 : 0;
}

static void *return_argument(void *argument)
{
    return argument;
}

static int create_call(void)
{
    pthread_t sentinel = (pthread_t)(uintptr_t)0x12345678;
    pthread_t handle = sentinel;
    errno = EDOM;
    if (pthread_create(&handle, NULL, return_argument, &token) || errno != EDOM)
        return 21;
    if (memcmp(&handle, &sentinel, sizeof handle) == 0)
        return 22;
    void *result = NULL;
    return pthread_join(handle, &result) == 0 && result == &token ? 0 : 23;
}

static int self_call(void)
{
    errno = EDOM;
    pthread_t self = pthread_self();
    if (!(uintptr_t)self)
        return 31;
    if (errno != EDOM)
        return 32;
    return pthread_equal(self, pthread_self()) && errno == EDOM ? 0 : 33;
}

static int equal_call(void)
{
    pthread_t self = pthread_self();
    errno = EDOM;
    if (!pthread_equal(self, self))
        return 35;
    return errno == EDOM ? 0 : 36;
}

static int join_call(void)
{
    pthread_t handle;
    if (pthread_create(&handle, NULL, return_argument, &token))
        return 40;
    void *result = NULL;
    errno = EDOM;
    if (pthread_join(handle, &result) || result != &token)
        return 41;
    return errno == EDOM ? 0 : 42;
}

static int join_self(void)
{
    void *result = &token;
    pthread_t self = pthread_self();
    errno = EDOM;
    if (pthread_join(self, &result) != EDEADLK)
        return 44;
    return result == &token && errno == EDOM ? 0 : 45;
}

static void *finish_detached(void *opaque)
{
    struct job *job = opaque;
    if (wait_flag(&job->release))
        release_flag(&job->ready);
    return NULL;
}

static int detach_call(void)
{
    struct job job = {0};
    pthread_t worker;
    if (pthread_create(&worker, NULL, finish_detached, &job))
        return 46;
    errno = EDOM;
    if (pthread_detach(worker) || errno != EDOM)
        return 47;
    release_flag(&job.release);
    return wait_flag(&job.ready) ? 0 : 48;
}

static void *exit_argument(void *argument)
{
    pthread_exit(argument);
}

static int exit_survivor(void)
{
    pthread_t handle;
    void *result = NULL;
    static const char message[] = "worker result\n";
    if (pthread_create(&handle, NULL, exit_argument, &token) ||
        pthread_join(handle, &result) || result != &token)
        return 51;
    return write(STDOUT_FILENO, message, sizeof message - 1) == sizeof message - 1 ? 0 : 52;
}

static void after_last(void)
{
    static const char message[] = "last exit\n";
    (void)write(STDOUT_FILENO, message, sizeof message - 1);
}

static void *join_initial(void *unused)
{
    (void)unused;
    static const char message[] = "initial joined\n";
    void *result = NULL;
    if (pthread_join(initial, &result) || result != &token)
        _exit(54);
    if (write(STDOUT_FILENO, message, sizeof message - 1) != sizeof message - 1)
        _exit(55);
    return NULL;
}

static int exit_initial(void)
{
    pthread_t worker;
    initial = pthread_self();
    if (atexit(after_last) || pthread_create(&worker, NULL, join_initial, NULL))
        return 53;
    pthread_exit(&token);
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    const char *mode = argv[1];
    if (strcmp(mode, "tls") == 0)
        return tls_workers();
    if (strcmp(mode, "create") == 0)
        return create_call();
    if (strcmp(mode, "self") == 0)
        return self_call();
    if (strcmp(mode, "equal") == 0)
        return equal_call();
    if (strcmp(mode, "join") == 0)
        return join_call();
    if (strcmp(mode, "join-self") == 0)
        return join_self();
    if (strcmp(mode, "detach") == 0)
        return detach_call();
    if (strcmp(mode, "exit-survivor") == 0)
        return exit_survivor();
    if (strcmp(mode, "exit-initial") == 0)
        return exit_initial();
    return 91;
}
