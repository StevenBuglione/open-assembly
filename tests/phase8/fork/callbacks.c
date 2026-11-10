#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

static int parent_pipe[2], child_pipe[2];
static int dynamic, registered, register_status;
static volatile sig_atomic_t failed_write;
static const int entry_error = 173;

static int correct_mask(void)
{
    sigset_t current;
    return sigprocmask(SIG_SETMASK, NULL, &current) == 0 &&
           sigismember(&current, SIGUSR1) == 1 && sigismember(&current, SIGUSR2) == 0;
}

static void publish(int fd, char byte, int check_mask)
{
    if (check_mask && !correct_mask())
        byte = '?';
    if (write(fd, &byte, 1) != 1)
        failed_write = 1;
    errno = ERANGE;
}

static void prepare_c(void) { publish(parent_pipe[1], 'c', 1); }
static void parent_c(void) { publish(parent_pipe[1], 'C', 1); }
static void child_c(void) { publish(child_pipe[1], '3', 1); }
static void prepare_a(void) { publish(parent_pipe[1], 'a', 1); }
static void parent_a(void) { publish(parent_pipe[1], 'A', 1); }
static void child_a(void) { publish(child_pipe[1], '1', 1); }
static void parent_b(void) { publish(parent_pipe[1], 'B', 1); }
static void child_b(void) { publish(child_pipe[1], '2', 1); }

static void prepare_b(void)
{
    if (dynamic && !registered) {
        registered = 1;
        register_status = pthread_atfork(prepare_c, parent_c, child_c);
    }
    publish(parent_pipe[1], 'b', 1);
}

static int expect_stream(int fd, const char *expected)
{
    char output[32], extra;
    ssize_t count = read(fd, output, sizeof output);
    if (count != (ssize_t)strlen(expected) || memcmp(output, expected, (size_t)count))
        return 0;
    return read(fd, &extra, 1) == -1 && (errno == EAGAIN || errno == EWOULDBLOCK);
}

static int once(const char *parent, const char *child)
{
    pid_t original = getpid();
    errno = entry_error;
    pid_t pid = fork();
    int error = errno;
    if (pid == 0) {
        if (getpid() == original)
            _exit(19);
#ifndef OA_PHASE8_HOST
        if (error != entry_error)
            _exit(20);
#endif
        _exit(failed_write || !correct_mask() ? 21 : 0);
    }
    if (pid < 0 || failed_write || !correct_mask())
        return 11;
#ifndef OA_PHASE8_HOST
    if (error != entry_error)
        return 12;
#else
    (void)error;
#endif
    int status;
    if (waitpid(pid, &status, 0) != pid || !WIFEXITED(status) || WEXITSTATUS(status))
        return 13;
    if (!expect_stream(parent_pipe[0], parent) || !expect_stream(child_pipe[0], child))
        return 14;
    return register_status ? 15 : 0;
}

static int callbacks(void)
{
    if (pipe2(parent_pipe, O_CLOEXEC | O_NONBLOCK) || pipe2(child_pipe, O_CLOEXEC | O_NONBLOCK))
        return 90;
    sigset_t mask;
    if (sigemptyset(&mask) || sigaddset(&mask, SIGUSR1) ||
        sigprocmask(SIG_SETMASK, &mask, NULL))
        return 91;
    if (pthread_atfork(prepare_a, parent_a, child_a) || pthread_atfork(prepare_b, parent_b, child_b))
        return 16;
    int result = once("baAB", "12");
    if (!result)
        result = dynamic ? once("cbaABC", "123") : once("baAB", "12");
    if (close(parent_pipe[0]) || close(parent_pipe[1]) || close(child_pipe[0]) || close(child_pipe[1]))
        return 92;
    return result;
}

static int capacity(void)
{
    for (int i = 0; i < 32; ++i) {
        errno = 373 + i;
        if (pthread_atfork(NULL, NULL, NULL) || errno != 373 + i)
            return 17;
    }
    errno = 619;
    if (pthread_atfork(NULL, NULL, NULL) != ENOMEM || errno != 619)
        return 18;
    return pthread_atfork(prepare_a, parent_a, child_a) == ENOMEM && errno == 619 ? 0 : 18;
}

static unsigned start_workers;

struct registrations { unsigned success, full, failure; };

static void *register_worker(void *argument)
{
    struct registrations *result = argument;
    while (!__atomic_load_n(&start_workers, __ATOMIC_ACQUIRE))
        ;
    for (unsigned i = 0; i < 12; ++i) {
        errno = 700 + (int)i;
        int status = pthread_atfork(NULL, NULL, NULL);
        if (errno != 700 + (int)i)
            ++result->failure;
        else if (!status)
            ++result->success;
        else if (status == ENOMEM)
            ++result->full;
        else
            ++result->failure;
    }
    return NULL;
}

static int concurrent(void)
{
    pthread_t threads[4];
    struct registrations results[4] = {{0}};
    size_t created = 0;
    for (; created < sizeof threads / sizeof *threads; ++created)
        if (pthread_create(&threads[created], NULL, register_worker, &results[created]))
            break;
    __atomic_store_n(&start_workers, 1, __ATOMIC_RELEASE);
    unsigned success = 0, full = 0;
    for (size_t i = 0; i < created; ++i) {
        if (pthread_join(threads[i], NULL) || results[i].failure)
            return 95;
        success += results[i].success;
        full += results[i].full;
    }
    if (created != sizeof threads / sizeof *threads)
        return 96;
    errno = EDOM;
    return success == 32 && full == 16 && pthread_atfork(NULL, NULL, NULL) == ENOMEM && errno == EDOM ? 0 : 22;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 93;
    if (!strcmp(argv[1], "capacity"))
        return capacity();
    if (!strcmp(argv[1], "concurrent"))
        return concurrent();
    if (strcmp(argv[1], "ordered") && strcmp(argv[1], "dynamic"))
        return 94;
    dynamic = !strcmp(argv[1], "dynamic");
    return callbacks();
}
