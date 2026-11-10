#include "kernel_abi.h"
#include <sys/stat.h>

_Static_assert(sizeof(off_t) == 8 && (off_t)-1 < 0, "signed 64-bit off_t");
_Static_assert(sizeof(mode_t) == 4 && (mode_t)-1 > 0, "unsigned 32-bit mode_t");

static int seeded(const char *path, const char *bytes, size_t count, int flags)
{
    int fd = (int)raw_open(AT_FDCWD, path, O_RDWR | O_CREAT | O_EXCL | flags, 0600);
    if (fd < 0 || raw_write(fd, bytes, count) != (long)count || raw_seek(fd, 0, SEEK_SET) != 0)
        return -1;
    return fd;
}

static int open_case(void)
{
    int seed = seeded("source", "F", 1, 0);
    if (seed < 0 || raw_close(seed))
        return 11;
    errno = TEST_ERRNO;
    int fd = open("source", O_RDONLY);
    char c = 0;
    if (fd < 0 || errno != TEST_ERRNO || raw_read(fd, &c, 1) != 1 || c != 'F')
        return 12;
    if (raw_close(fd))
        return 13;

    fd = open(".", O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0 || raw_fcntl(fd, K_F_GETFD, 0) != K_FD_CLOEXEC || raw_close(fd))
        return 14;
    if (kernel_call(__NR_umask, 0027, 0, 0, 0, 0, 0) < 0)
        return 15;
    fd = open("created", O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC, (mode_t)0677);
    struct kernel_stat sb;
    if (fd < 0 || errno != TEST_ERRNO || raw_fstat(fd, &sb) || (sb.mode & 0777) != 0650 ||
        raw_fcntl(fd, K_F_GETFD, 0) != K_FD_CLOEXEC || raw_close(fd))
        return 16;
    if (open("created", O_RDWR | O_CREAT | O_EXCL, (mode_t)0777) != -1 || errno != EEXIST)
        return 17;
    if (open("missing", O_RDONLY) != -1 || errno != ENOENT)
        return 18;
    if (open("source", O_RDONLY | O_DIRECTORY) != -1 || errno != ENOTDIR)
        return 19;

    /* Compare the complete O_TMPFILE pattern to the kernel on this filesystem. */
    int flags = O_TMPFILE | O_RDWR | O_CLOEXEC;
    long reference = raw_open(AT_FDCWD, ".", flags, 0666);
    errno = TEST_ERRNO;
    fd = open(".", flags, (mode_t)0666);
    if (reference < 0) {
        if (fd != -1 || errno != -reference)
            return 20;
    } else {
        if (fd < 0 || errno != TEST_ERRNO || raw_fstat(fd, &sb) ||
            (sb.mode & 0777) != 0640 || sb.links ||
            raw_fcntl(fd, K_F_GETFD, 0) != K_FD_CLOEXEC ||
            raw_close(fd) || raw_close((int)reference))
            return 21;
    }
    return raw_unlink("created", 0) || raw_unlink("source", 0) ? 22 : 0;
}

static int openat_case(void)
{
    if (raw_mkdir("directory", 0700))
        return 31;
    int fd = seeded("file", "C", 1, 0);
    int inner = seeded("directory/file", "D", 1, 0);
    int dir = (int)raw_open(AT_FDCWD, "directory", O_RDONLY | O_DIRECTORY, 0);
    if (fd < 0 || inner < 0 || dir < 0 || raw_close(inner))
        return 32;
    errno = TEST_ERRNO;
    int got = openat(dir, "file", O_RDONLY);
    char c = 0;
    if (got < 0 || errno != TEST_ERRNO || raw_read(got, &c, 1) != 1 || c != 'D')
        return 33;
    if (raw_close(got))
        return 34;
    got = openat(AT_FDCWD, "file", O_RDONLY);
    if (got < 0 || raw_read(got, &c, 1) != 1 || c != 'C' || raw_close(got))
        return 35;
    got = openat(-1, "/dev/null", O_RDONLY);
    if (got < 0 || raw_close(got))
        return 36;
    if (openat(-1, "file", O_RDONLY) != -1 || errno != EBADF ||
        openat(fd, "file", O_RDONLY) != -1 || errno != ENOTDIR)
        return 37;
    if (kernel_call(__NR_umask, 0007, 0, 0, 0, 0, 0) < 0)
        return 38;
    errno = TEST_ERRNO;
    got = openat(dir, "new", O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, (mode_t)0666);
    struct kernel_stat sb;
    if (got < 0 || errno != TEST_ERRNO || raw_stat(dir, "new", 0, &sb) ||
        (sb.mode & 0777) != 0660 || raw_fcntl(got, K_F_GETFD, 0) != K_FD_CLOEXEC)
        return 39;
    return raw_close(got) || raw_close(fd) || raw_close(dir) ||
           raw_unlink("directory/new", 0) || raw_unlink("directory/file", 0) ||
           raw_unlink("directory", K_AT_REMOVEDIR) || raw_unlink("file", 0) ? 40 : 0;
}

static int creat_case(void)
{
    int original = seeded("existing", "bytes", 5, 0);
    if (original < 0 || kernel_call(__NR_umask, 0027, 0, 0, 0, 0, 0) < 0)
        return 51;
    errno = TEST_ERRNO;
    int fd = creat("existing", 0777);
    struct kernel_stat sb;
    if (fd < 0 || errno != TEST_ERRNO || raw_fstat(original, &sb) ||
        sb.size != 0 || (sb.mode & 0777) != 0600)
        return 52;
    if ((raw_fcntl(fd, K_F_GETFL, 0) & O_ACCMODE) != O_WRONLY ||
        raw_write(fd, "new", 3) != 3 || raw_close(fd))
        return 53;
    fd = creat("new", 0777);
    if (fd < 0 || errno != TEST_ERRNO || raw_fstat(fd, &sb) || (sb.mode & 0777) != 0750)
        return 54;
    return raw_close(fd) || raw_close(original) || raw_unlink("new", 0) ||
           raw_unlink("existing", 0) ? 55 : 0;
}

static int seek_case(void)
{
    int fd = seeded("sparse", "S", 1, 0);
    if (fd < 0)
        return 61;
    const off_t far = (1L << 33) + 9;
    errno = TEST_ERRNO;
    if (lseek(fd, far, SEEK_SET) != far || errno != TEST_ERRNO ||
        raw_seek(fd, 0, SEEK_CUR) != far || raw_write(fd, "Z", 1) != 1)
        return 62;
    if (lseek(fd, -2, SEEK_CUR) != far - 1 || lseek(fd, -2, SEEK_END) != far - 1)
        return 63;
    unsigned char tail[2] = {0xFF, 0xFF};
    if (raw_read(fd, tail, 2) != 2 || tail[0] != 0 || tail[1] != 'Z')
        return 64;
    if (lseek(fd, -1, SEEK_SET) != -1 || errno != EINVAL ||
        raw_seek(fd, 0, SEEK_CUR) != far + 1)
        return 65;
    int ends[2];
    if (kernel_call(__NR_pipe2, (long)ends, 0, 0, 0, 0, 0) || raw_close(fd) ||
        raw_unlink("sparse", 0))
        return 66;
    if (lseek(ends[0], 0, SEEK_SET) != -1 || errno != ESPIPE)
        return 67;
    return raw_close(ends[0]) || raw_close(ends[1]) ? 68 : 0;
}

static int dup_case(void)
{
    int fd = seeded("shared", "AB", 2, O_CLOEXEC);
    int lower = (int)raw_open(AT_FDCWD, "/dev/null", O_RDONLY, 0);
    if (fd < 0 || lower < 0 || raw_close(lower))
        return 71;
    errno = TEST_ERRNO;
    int copy = dup(fd);
    if (copy != lower || errno != TEST_ERRNO || raw_fcntl(copy, K_F_GETFD, 0) != 0 ||
        raw_fcntl(fd, K_F_GETFD, 0) != K_FD_CLOEXEC)
        return 72;
    char c = 0;
    if (raw_read(fd, &c, 1) != 1 || c != 'A' ||
        raw_read(copy, &c, 1) != 1 || c != 'B' || raw_seek(fd, 0, SEEK_CUR) != 2)
        return 73;
    if (dup(-1) != -1 || errno != EBADF)
        return 74;
    return raw_close(copy) || raw_close(fd) || raw_unlink("shared", 0) ? 75 : 0;
}

static int dup2_case(void)
{
    int fd = seeded("source", "AB", 2, O_CLOEXEC);
    int copy = seeded("target", "CD", 2, O_CLOEXEC);
    if (fd < 0 || copy < 0)
        return 81;
    errno = TEST_ERRNO;
    if (dup2(fd, copy) != copy || errno != TEST_ERRNO || raw_fcntl(copy, K_F_GETFD, 0) != 0)
        return 82;
    if (dup2(fd, fd) != fd || raw_fcntl(fd, K_F_GETFD, 0) != K_FD_CLOEXEC)
        return 83;
    if (dup2(-1, copy) != -1 || errno != EBADF)
        return 84;
    char c = 0;
    if (raw_read(copy, &c, 1) != 1 || c != 'A' ||
        raw_read(fd, &c, 1) != 1 || c != 'B')
        return 85;
    return raw_close(copy) || raw_close(fd) ||
           raw_unlink("source", 0) || raw_unlink("target", 0) ? 86 : 0;
}

static int pipe_case(void)
{
    int slots[4] = {0x12345678, -100, -200, 0x23456789};
    errno = TEST_ERRNO;
    if (pipe(&slots[1]) != 0 || errno != TEST_ERRNO ||
        slots[0] != 0x12345678 || slots[3] != 0x23456789 ||
        slots[1] < 0 || slots[2] < 0 || slots[1] == slots[2])
        return 92;
    int reader = slots[1], writer = slots[2];
    long reader_flags = raw_fcntl(reader, K_F_GETFL, 0);
    long writer_flags = raw_fcntl(writer, K_F_GETFL, 0);
    if (reader_flags < 0 || writer_flags < 0 ||
        (reader_flags & (O_ACCMODE | O_NONBLOCK)) != O_RDONLY ||
        (writer_flags & (O_ACCMODE | O_NONBLOCK)) != O_WRONLY ||
        raw_fcntl(reader, K_F_GETFD, 0) || raw_fcntl(writer, K_F_GETFD, 0))
        return 93;
    char c = 0;
    if (raw_write(writer, "P", 1) != 1 || raw_read(reader, &c, 1) != 1 || c != 'P' ||
        raw_close(writer) || raw_read(reader, &c, 1) != 0 || raw_close(reader))
        return 94;
    return 0;
}

static int pipe_exhaustion(void)
{
    /* Linux RLIMIT_NOFILE is 7. Existing descriptors remain valid. */
    const unsigned long limit[2] = {3, 3};
    if (kernel_call(__NR_prlimit64, 0, 7, (long)limit, 0, 0, 0))
        return 101;
    int slots[4] = {0x12345678, -100, -200, 0x23456789};
    errno = TEST_ERRNO;
    if (pipe(&slots[1]) != -1 || errno != EMFILE ||
        slots[0] != 0x12345678 || slots[1] != -100 ||
        slots[2] != -200 || slots[3] != 0x23456789)
        return 102;
    return 0;
}

static int mkdir_case(void)
{
    if (kernel_call(__NR_umask, 0027, 0, 0, 0, 0, 0) < 0)
        return 111;
    errno = TEST_ERRNO;
    if (mkdir("directory", 0777) || errno != TEST_ERRNO)
        return 112;
    struct kernel_stat sb;
    if (raw_stat(AT_FDCWD, "directory", 0, &sb) ||
        (sb.mode & (S_IFMT | 0777)) != (S_IFDIR | 0750))
        return 113;
    if (mkdir("directory", 0700) != -1 || errno != EEXIST ||
        mkdir("missing/child", 0700) != -1 || errno != ENOENT)
        return 114;
    return raw_unlink("directory", K_AT_REMOVEDIR) ? 115 : 0;
}

static int rmdir_case(void)
{
    if (raw_mkdir("directory", 0700))
        return 121;
    int fd = seeded("directory/file", "x", 1, 0);
    if (fd < 0 || raw_close(fd))
        return 122;
    if (rmdir("directory") != -1 || errno != ENOTEMPTY)
        return 123;
    if (raw_unlink("directory/file", 0))
        return 124;
    errno = TEST_ERRNO;
    struct kernel_stat sb;
    if (rmdir("directory") || errno != TEST_ERRNO || raw_stat(AT_FDCWD, "directory", 0, &sb) != -ENOENT)
        return 125;
    return rmdir("directory") != -1 || errno != ENOENT ? 126 : 0;
}

static int unlink_case(void)
{
    int fd = seeded("name", "U", 1, 0);
    if (fd < 0)
        return 131;
    errno = TEST_ERRNO;
    if (unlink("name") || errno != TEST_ERRNO)
        return 132;
    struct kernel_stat sb;
    char c = 0;
    if (raw_stat(AT_FDCWD, "name", 0, &sb) != -ENOENT || raw_fstat(fd, &sb) ||
        sb.links || raw_read(fd, &c, 1) != 1 || c != 'U')
        return 133;
    if (unlink("name") != -1 || errno != ENOENT)
        return 134;
    return raw_close(fd) ? 135 : 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    if (kernel_call(__NR_umask, 0, 0, 0, 0, 0, 0) < 0)
        return 3;
    const char *mode = argv[1];
    if (same_text(mode, "open")) return open_case();
    if (same_text(mode, "openat")) return openat_case();
    if (same_text(mode, "creat")) return creat_case();
    if (same_text(mode, "lseek")) return seek_case();
    if (same_text(mode, "dup")) return dup_case();
    if (same_text(mode, "dup2")) return dup2_case();
    if (same_text(mode, "pipe")) return pipe_case();
    if (same_text(mode, "pipe-exhaustion")) return pipe_exhaustion();
    if (same_text(mode, "mkdir")) return mkdir_case();
    if (same_text(mode, "rmdir")) return rmdir_case();
    if (same_text(mode, "unlink")) return unlink_case();
    return 2;
}
