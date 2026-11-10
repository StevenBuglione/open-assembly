#ifndef OA_PHASE6_KERNEL_ABI_H
#define OA_PHASE6_KERNEL_ABI_H

#if defined(OA_PHASE6_HOST) && !defined(_GNU_SOURCE)
# define _GNU_SOURCE
#endif

#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <unistd.h>

#ifdef OA_PHASE6_HOST
# include <sys/syscall.h>
static inline long kernel_call(long number, long a1, long a2, long a3, long a4, long a5, long a6)
{
    int saved = errno;
    long result = syscall(number, a1, a2, a3, a4, a5, a6);
    if (result == -1)
        result = -errno;
    errno = saved;
    return result;
}
#else
# include <asm/unistd.h>
long __al_syscall(long number, long a1, long a2, long a3, long a4, long a5, long a6);
# define kernel_call __al_syscall
#endif

/* Linux x86-64 UAPI asm-generic/fcntl.h values for the raw oracle. */
enum {
    K_F_GETFD = 1, K_F_SETFD = 2, K_F_GETFL = 3, K_FD_CLOEXEC = 1,
    K_AT_SYMLINK_NOFOLLOW = 0x100, K_AT_REMOVEDIR = 0x200, K_AT_EMPTY_PATH = 0x1000
};
enum { TEST_ERRNO = 947 };

static inline long raw_open(int dirfd, const char *path, int flags, unsigned mode)
{
    return kernel_call(__NR_openat, dirfd, (long)path, flags, mode, 0, 0);
}

static inline long raw_mkdir(const char *path, unsigned mode)
{
    return kernel_call(__NR_mkdirat, AT_FDCWD, (long)path, mode, 0, 0, 0);
}

static inline long raw_unlink(const char *path, int flags)
{
    return kernel_call(__NR_unlinkat, AT_FDCWD, (long)path, flags, 0, 0, 0);
}

static inline long raw_close(int fd)
{
    return kernel_call(__NR_close, fd, 0, 0, 0, 0, 0);
}

static inline long raw_read(int fd, void *buffer, size_t size)
{
    return kernel_call(__NR_read, fd, (long)buffer, size, 0, 0, 0);
}

static inline long raw_write(int fd, const void *buffer, size_t size)
{
    return kernel_call(__NR_write, fd, (long)buffer, size, 0, 0, 0);
}

static inline long raw_fcntl(int fd, int cmd, int value)
{
    return kernel_call(__NR_fcntl, fd, cmd, value, 0, 0, 0);
}

static inline long raw_seek(int fd, long offset, int whence)
{
    return kernel_call(__NR_lseek, fd, offset, whence, 0, 0, 0);
}

static inline int same_text(const char *left, const char *right)
{
    while (*left && *left == *right) {
        ++left;
        ++right;
    }
    return *left == *right;
}

/* Linux arch/x86/include/uapi/asm/stat.h LP64 record. */
struct kernel_stat {
    unsigned long device, inode, links;
    unsigned mode, uid, gid, reserved;
    unsigned long rdevice;
    long size, block_size, blocks;
    long atime_seconds, atime_ns, mtime_seconds, mtime_ns, ctime_seconds, ctime_ns;
    long unused[3];
};
_Static_assert(sizeof(struct kernel_stat) == 144 && _Alignof(struct kernel_stat) == 8,
               "Linux x86-64 stat size and alignment");

static inline long raw_fstat(int fd, struct kernel_stat *result)
{
    return kernel_call(__NR_fstat, fd, (long)result, 0, 0, 0, 0);
}

static inline long raw_stat(int fd, const char *path, int flags, struct kernel_stat *result)
{
    return kernel_call(__NR_newfstatat, fd, (long)path, (long)result, flags, 0, 0);
}

#endif
