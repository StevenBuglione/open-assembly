#include "../kernel_abi.h"
#include <stdio.h>
#include <stdlib.h>

enum case_mode { disabled, mkstemp_retry, tmpfile_fallback };
static enum case_mode armed;
static unsigned random_calls, collision_calls, anonymous_calls, named_calls;
static int fallback_fd = -1;

long __real___al_syscall(long, long, long, long, long, long, long);

static int prefix(const char *text, const char *wanted)
{
    while (*wanted) {
        if (*text++ != *wanted++)
            return 0;
    }
    return 1;
}

long __wrap___al_syscall(long nr, long a1, long a2, long a3, long a4, long a5, long a6)
{
    if (armed == mkstemp_retry && nr == __NR_getrandom && a1 && a2 > 0) {
        ++random_calls;
        if (random_calls == 1)
            return -EINTR;
    }
    if (nr == __NR_openat && a2) {
        const char *path = (const char *)a2;
        const long create_exclusive = O_CREAT | O_EXCL;
        if (armed == mkstemp_retry && (a3 & create_exclusive) == create_exclusive &&
            prefix(path, "retry-")) {
            ++collision_calls;
            if (collision_calls == 1)
                return -EEXIST;
        }
        if (armed == tmpfile_fallback && (a3 & O_TMPFILE) == O_TMPFILE && same_text(path, "/tmp")) {
            ++anonymous_calls;
            return -EOPNOTSUPP;
        }
        if (armed == tmpfile_fallback && (a3 & create_exclusive) == create_exclusive &&
            prefix(path, "/tmp/")) {
            ++named_calls;
            long result = __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
            if (result >= 0)
                fallback_fd = (int)result;
            return result;
        }
    }
    return __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
}

static int retry(void)
{
    char path[] = "retry-XXXXXX";
    errno = TEST_ERRNO;
    armed = mkstemp_retry;
    int fd = mkstemp(path);
    armed = disabled;
    if (fd < 3 || errno != TEST_ERRNO || random_calls < 2 || collision_calls < 2)
        return 11;
    struct kernel_stat open_file, named_file;
    if (raw_fstat(fd, &open_file) || raw_stat(AT_FDCWD, path, 0, &named_file) ||
        open_file.inode != named_file.inode || open_file.device != named_file.device)
        return 12;
    return raw_close(fd) || raw_unlink(path, 0) ? 13 : 0;
}

static int fallback(void)
{
    errno = TEST_ERRNO;
    armed = tmpfile_fallback;
    FILE *file = tmpfile();
    armed = disabled;
    if (!file || errno != TEST_ERRNO || anonymous_calls != 1 || !named_calls || fallback_fd < 3)
        return 21;
    struct kernel_stat status;
    if (raw_fstat(fallback_fd, &status) || status.links ||
        raw_fcntl(fallback_fd, K_F_GETFD, 0) != K_FD_CLOEXEC ||
        fputc('T', file) != 'T' || fseek(file, 0, SEEK_SET) || fgetc(file) != 'T')
        return 22;
    return fclose(file) || raw_fcntl(fallback_fd, K_F_GETFD, 0) != -EBADF ? 23 : 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    if (same_text(argv[1], "retry")) return retry();
    if (same_text(argv[1], "fallback")) return fallback();
    return 2;
}
