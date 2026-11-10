#include "kernel_abi.h"
#include <dirent.h>
#include <stdint.h>
#include <sys/stat.h>

unsigned phase2_abi_probe(uintptr_t function, const uint64_t arguments[6]);
int probe_open(const char *path, int flags);
int probe_openat(int fd, const char *path, int flags);

#define PROBE(function, ...) \
    phase2_abi_probe((uintptr_t)(function), (const uint64_t[6]){__VA_ARGS__})

static int file_abi(void)
{
    static const char missing[] = "missing";
    const uint64_t path = (uintptr_t)missing;
    const uint64_t bad_fd = UINT64_C(0xA2345678FFFFFFFF);
    if (PROBE(probe_open, path, O_RDONLY) || PROBE(probe_openat, bad_fd, path, O_RDONLY) ||
        PROBE(creat, (uintptr_t)"missing/file", 0600))
        return 11;
    if (PROBE(lseek, bad_fd, 0, SEEK_SET) || PROBE(dup, bad_fd) ||
        PROBE(dup2, bad_fd, bad_fd))
        return 12;
    int ends[2] = {-1, -1};
    if (PROBE(pipe, (uintptr_t)ends) || ends[0] < 0 || ends[1] < 0 ||
        raw_close(ends[0]) || raw_close(ends[1]))
        return 13;
    if (PROBE(mkdir, (uintptr_t)"missing/dir", 0700) ||
        PROBE(rmdir, path) || PROBE(unlink, path))
        return 14;
    return 0;
}

static int info_abi(void)
{
    struct stat sb;
    const uint64_t out = (uintptr_t)&sb;
    const uint64_t cwd = (uintptr_t)".";
    int fd = (int)raw_open(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY, 0);
    if (fd < 0)
        return 21;
    if (PROBE(stat, cwd, out) || PROBE(lstat, cwd, out) || PROBE(fstat, fd, out) ||
        PROBE(fstatat, fd, cwd, out, 0))
        return 22;
    if (PROBE(opendir, (uintptr_t)"missing") || PROBE(fdopendir, UINT64_MAX))
        return 23;
    DIR *dir = fdopendir(fd);
    if (!dir)
        return 24;
    if (PROBE(dirfd, (uintptr_t)dir) || PROBE(readdir, (uintptr_t)dir) ||
        PROBE(closedir, (uintptr_t)dir) || raw_fcntl(fd, K_F_GETFD, 0) != -EBADF)
        return 25;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    if (same_text(argv[1], "files")) return file_abi();
    if (same_text(argv[1], "info")) return info_abi();
    return 2;
}
