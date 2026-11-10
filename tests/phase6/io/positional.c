#include "fixture.h"

static const long far = (long)UINT64_C(0x400000003);

static int read_at(int fd)
{
    const char expected[3] = {'a', 'b', 'c'};
    if (raw_pwrite(fd, expected, 3, far) != 3 || raw_seek(fd, 21, SEEK_SET) != 21)
        return 90;
    unsigned char data[5] = {0xa5, 0xa5, 0xa5, 0xa5, 0xa5};
    errno = TEST_ERRNO;
    if (pread(fd, data, 4, far) != 3 || data[0] != 'a' || data[1] != 'b' ||
        data[2] != 'c' || data[3] != 0xa5 || data[4] != 0xa5 || errno != TEST_ERRNO ||
        raw_seek(fd, 0, SEEK_CUR) != 21)
        return 11;
    if (pread(fd, data, 4, far + 3) != 0 || pread(fd, data, 0, far) != 0 ||
        data[3] != 0xa5 || errno != TEST_ERRNO || raw_seek(fd, 0, SEEK_CUR) != 21)
        return 12;
    if (pread(fd, data, 1, -1) != -1 || errno != EINVAL ||
        pread(-1, data, 1, 0) != -1 || errno != EBADF || data[3] != 0xa5)
        return 13;
    int pair[2];
    if (raw_pipe(pair))
        return 91;
    if (pread(pair[0], data, 1, 0) != -1 || errno != ESPIPE || data[3] != 0xa5)
        return 14;
    return raw_close(pair[0]) || raw_close(pair[1]) ? 92 : 0;
}

static int write_at(int fd)
{
    const char payload[] = {'a', 'b', 'c'};
    if (raw_seek(fd, 21, SEEK_SET) != 21)
        return 90;
    errno = TEST_ERRNO;
    if (pwrite(fd, payload, sizeof payload, far) != sizeof payload || errno != TEST_ERRNO ||
        raw_seek(fd, 0, SEEK_CUR) != 21)
        return 11;
    char bytes[3];
    if (raw_pread(fd, bytes, sizeof bytes, far) != sizeof bytes ||
        bytes[0] != 'a' || bytes[1] != 'b' || bytes[2] != 'c')
        return 12;
    if (pwrite(fd, payload, 0, far + 400) != 0 || errno != TEST_ERRNO ||
        raw_seek(fd, 0, SEEK_CUR) != 21 || raw_seek(fd, 0, SEEK_END) != far + 3)
        return 13;
    if (pwrite(fd, payload, 0, -1) != -1 || errno != EINVAL ||
        pwrite(fd, payload, 1, -1) != -1 || errno != EINVAL ||
        pwrite(-1, payload, 1, 0) != -1 || errno != EBADF)
        return 14;
    int pair[2];
    if (raw_pipe(pair))
        return 91;
    if (pwrite(pair[1], payload, 1, 0) != -1 || errno != ESPIPE)
        return 15;
    return raw_close(pair[0]) || raw_close(pair[1]) ? 92 : 0;
}

int main(int argc, char **argv)
{
    if (argc != 2 || (!same_text(argv[1], "pread") && !same_text(argv[1], "pwrite")))
        return 93;
    int fd = memory_file();
    if (fd < 0)
        return 94;
    int status = same_text(argv[1], "pread") ? read_at(fd) : write_at(fd);
    if (raw_close(fd))
        return 95;
    return status;
}
