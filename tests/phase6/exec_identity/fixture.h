#ifndef OA_EXEC_IDENTITY_FIXTURE_H
#define OA_EXEC_IDENTITY_FIXTURE_H

#include "../kernel_abi.h"

#include <stdint.h>
#include <sys/wait.h>

enum operation { EXECVE, EXECV, EXECVP, BAD_OPERATION };

static inline enum operation operation_from(const char *name)
{
    if (same_text(name, "execve"))
        return EXECVE;
    if (same_text(name, "execv"))
        return EXECV;
    if (same_text(name, "execvp"))
        return EXECVP;
    return BAD_OPERATION;
}

static inline int attempt(enum operation operation, const char *path, char **argv, char **env)
{
    if (operation == EXECVE)
        return execve(path, argv, env);
    if (operation == EXECV)
        return execv(path, argv);
    return execvp(path, argv);
}

static inline int write_all(int fd, const void *data, size_t size)
{
    size_t used = 0;
    while (used < size) {
        long n = raw_write(fd, (const char *)data + used, size - used);
        if (n == -EINTR)
            continue;
        if (n <= 0)
            return 0;
        used += (size_t)n;
    }
    return 1;
}

static inline int make_file(const char *path, const char *text, size_t length, unsigned mode)
{
    int fd = (int)raw_open(AT_FDCWD, path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, mode);
    if (fd < 0)
        return 0;
    int written = write_all(fd, text, length);
    return raw_close(fd) == 0 && written;
}

static inline long identity(void)
{
    return kernel_call(__NR_getpid, 0, 0, 0, 0, 0, 0);
}

#endif
