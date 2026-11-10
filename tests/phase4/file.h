#ifndef AL_PHASE4_FILE_H
#define AL_PHASE4_FILE_H

#include "check.h"

#ifdef OA_PHASE4_HOST
# include <errno.h>
# include <sys/syscall.h>
# include <unistd.h>
static inline long kernel_call(long number, long a1, long a2, long a3, long a4, long a5, long a6)
{
    long result = syscall(number, a1, a2, a3, a4, a5, a6);
    return result == -1 ? -errno : result;
}
#else
# include <asm/unistd.h>
long __al_syscall(long number, long a1, long a2, long a3, long a4, long a5, long a6);
# define kernel_call __al_syscall
#endif

struct file_fixture {
    long fd;
    char path[48];
};

static inline int file_fixture_open(struct file_fixture *fixture, const void *bytes, size_t size)
{
    static const char prefix[] = "/proc/self/fd/";
    fixture->fd = kernel_call(__NR_memfd_create, (long)"open-assembly-stdio-test", 0, 0, 0, 0, 0);
    if (fixture->fd < 0)
        return 0;
    if (size && kernel_call(__NR_write, fixture->fd, (long)bytes, (long)size, 0, 0, 0) != (long)size)
        return 0;
    char reverse[24];
    size_t count = 0;
    unsigned long fd = (unsigned long)fixture->fd;
    do {
        reverse[count++] = (char)('0' + fd % 10);
        fd /= 10;
    } while (fd);
    size_t position = sizeof prefix - 1;
    for (size_t i = 0; i < position; ++i)
        fixture->path[i] = prefix[i];
    while (count)
        fixture->path[position++] = reverse[--count];
    fixture->path[position] = '\0';
    return 1;
}

static inline long file_fixture_read(const struct file_fixture *fixture, void *bytes, size_t size)
{
    return kernel_call(__NR_pread64, fixture->fd, (long)bytes, (long)size, 0, 0, 0);
}

static inline int file_fixture_close(const struct file_fixture *fixture)
{
    return kernel_call(__NR_close, fixture->fd, 0, 0, 0, 0, 0) == 0;
}

#endif
