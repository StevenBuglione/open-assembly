#define _GNU_SOURCE
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <spawn.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern pid_t _Fork(void);
static volatile sig_atomic_t callbacks;

static void observe_callback(void) { ++callbacks; }

static int wait_for(pid_t pid, int code)
{
    int status;
    return pid > 0 && waitpid(pid, &status, 0) == pid && WIFEXITED(status) && WEXITSTATUS(status) == code;
}

static int raw_fork(void)
{
    pid_t original = getpid();
    errno = EDOM;
    pid_t child = _Fork();
    int error = errno;
    if (!child) {
        if (getpid() == original)
            _exit(19);
        _exit(callbacks || error != EDOM ? 20 : 7);
    }
    return callbacks || error != EDOM || !wait_for(child, 7) ? 11 : 0;
}

static int shell_and_spawn(void)
{
    pid_t child = -1;
    char *args[] = {"sh", "-c", "exit 7", NULL};
    char *env[] = {"LC_ALL=C", NULL};
    if (posix_spawn(&child, "/bin/sh", NULL, NULL, args, env) || callbacks || !wait_for(child, 7))
        return 12;
    int status = system("exit 9");
    return callbacks || !WIFEXITED(status) || WEXITSTATUS(status) != 9 ? 13 : 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (pthread_atfork(observe_callback, observe_callback, observe_callback))
        return 91;
    if (!strcmp(argv[1], "raw"))
        return raw_fork();
    if (!strcmp(argv[1], "spawn"))
        return shell_and_spawn();
    return 92;
}
