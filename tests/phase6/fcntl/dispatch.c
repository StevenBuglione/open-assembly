#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdlib.h>
#include <unistd.h>

extern long __al_syscall(long, long, long, long, long, long, long);

struct command {
    int value;
    enum { NO_ARGUMENT, INTEGER, POINTER } argument;
};

static const struct command commands[] = {
    {F_GETFD, NO_ARGUMENT}, {F_GETFL, NO_ARGUMENT}, {F_GETOWN, NO_ARGUMENT},
    {F_GETPIPE_SZ, NO_ARGUMENT}, {F_DUPFD, INTEGER}, {F_DUPFD_CLOEXEC, INTEGER},
    {F_SETFD, INTEGER}, {F_SETFL, INTEGER}, {F_SETOWN, INTEGER}, {F_SETPIPE_SZ, INTEGER},
    {F_GETLK, POINTER}, {F_SETLK, POINTER}, {F_SETLKW, POINTER}, {F_OFD_GETLK, POINTER},
    {F_OFD_SETLK, POINTER}, {F_OFD_SETLKW, POINTER}, {F_GETOWN_EX, POINTER}, {F_SETOWN_EX, POINTER},
};

static int unsupported(int number)
{
    for (size_t i = 0; i < sizeof commands / sizeof commands[0]; ++i) {
        if (commands[i].value == number)
            return 1;
    }
    errno = EDOM;
    return fcntl(-1, number) == -1 && errno == EINVAL;
}

static int rejection(void)
{
    for (size_t i = 0; i < sizeof commands / sizeof commands[0]; ++i) {
        const struct command *cmd = &commands[i];
        struct flock lock = {.l_type = F_UNLCK};
        errno = EDOM;
        int status;
        switch (cmd->argument) {
        case NO_ARGUMENT:
            status = fcntl(-1, cmd->value);
            break;
        case INTEGER:
            status = fcntl(-1, cmd->value, 0);
            break;
        case POINTER:
            status = fcntl(-1, cmd->value, &lock);
            break;
        default:
            return 90;
        }
        if (status != -1 || errno != EBADF)
            return 10 + (int)i;
        if (!unsupported(cmd->value - 1) || !unsupported(cmd->value + 1))
            return 30 + (int)i;
    }
    return unsupported(INT_MIN) && unsupported(INT_MAX) ? 0 : 48;
}

static int valid(void)
{
    char file[] = "fcntl-dispatch-XXXXXX";
    int fd = mkstemp(file);
    int pipes[2];
    if (fd < 0 || unlink(file) || pipe(pipes))
        return 90;
    errno = EDOM;
    int flags = fcntl(fd, F_GETFL);
    int fd_flags = fcntl(fd, F_GETFD);
    if (flags < 0 || fd_flags < 0 || fcntl(fd, F_SETFD, FD_CLOEXEC) != 0 ||
        fcntl(fd, F_GETFD) != FD_CLOEXEC || fcntl(fd, F_SETFL, flags | O_NONBLOCK) ||
        fcntl(fd, F_GETFL) != (flags | O_NONBLOCK) || errno != EDOM)
        return 49;
    int fd1 = fcntl(fd, F_DUPFD, 41);
    int fd2 = fcntl(fd, F_DUPFD_CLOEXEC, 51);
    if (fd1 < 41 || fd2 < 51 || fd1 == fd2 || fcntl(fd1, F_GETFD) ||
        fcntl(fd2, F_GETFD) != FD_CLOEXEC || errno != EDOM)
        return 50;
    int capacity = fcntl(pipes[0], F_GETPIPE_SZ);
    int selected = fcntl(pipes[1], F_SETPIPE_SZ, 1);
    if (capacity <= 0 || selected <= 0 || selected > capacity ||
        fcntl(pipes[0], F_GETPIPE_SZ) != selected || errno != EDOM)
        return 51;

    struct flock lk = {.l_type = F_WRLCK, .l_whence = SEEK_SET, .l_start = 17, .l_len = 9};
    if (fcntl(fd, F_SETLKW, &lk) || fcntl(fd, F_GETLK, &lk) ||
        lk.l_type != F_UNLCK || errno != EDOM)
        return 52;
    if (fcntl(fd, F_SETLK, &lk) || errno != EDOM)
        return 53;
    lk.l_type = F_WRLCK;
    if (fcntl(fd, F_OFD_SETLKW, &lk) || fcntl(fd, F_OFD_GETLK, &lk) ||
        lk.l_type != F_UNLCK || fcntl(fd, F_OFD_SETLK, &lk) || errno != EDOM)
        return 54;

    pid_t pid = getpid();
    struct f_owner_ex owner = {.type = F_OWNER_PID, .pid = pid}, got = {.type = -1, .pid = -1};
    if (fcntl(pipes[0], F_SETOWN_EX, &owner) || fcntl(pipes[0], F_GETOWN_EX, &got) ||
        got.type != owner.type || got.pid != pid || fcntl(pipes[0], F_GETOWN) != pid || errno != EDOM)
        return 55;
    enum { SYS_GETPGRP = 111, SYS_SETPGID = 109 };
    long group = __al_syscall(SYS_GETPGRP, 0, 0, 0, 0, 0, 0);
    if (group == 1) {
        if (fcntl(pipes[0], F_SETOWN, -1) || fcntl(pipes[0], F_GETOWN) != -1 ||
            errno != EOVERFLOW)
            return 56;
        errno = EDOM;
    }
    if (group != pid && __al_syscall(SYS_SETPGID, 0, 0, 0, 0, 0, 0))
        return 90;
    if (pid <= 1 || fcntl(pipes[0], F_SETOWN, -pid) || fcntl(pipes[0], F_GETOWN) != -pid ||
        errno != EDOM)
        return 57;
    if (fcntl(pipes[0], F_SETOWN, 0) || fcntl(pipes[0], F_GETOWN) != 0 || errno != EDOM)
        return 58;
    if (close(fd2) || close(fd1) || close(fd) || close(pipes[0]) || close(pipes[1]))
        return 90;
    return 0;
}

int main(void)
{
    int status = rejection();
    return status ? status : valid();
}
