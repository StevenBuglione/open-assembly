#include "kernel_abi.h"

#include <stdint.h>

struct stimulus { uint64_t mode, value; };
struct observed { int64_t result, error, effect; };
_Static_assert(sizeof(struct stimulus) == 16 && sizeof(struct observed) == 24, "LP64 wire layout");

enum { K_MEMFD_CREATE = 319, K_MFD_CLOEXEC = 1, K_F_DUPFD = 0 };

static int memory_file(int close_on_exec)
{
    return (int)kernel_call(K_MEMFD_CREATE, (long)"oa-wrapper-fuzz", close_on_exec, 0, 0, 0, 0);
}

static int read_record(struct stimulus *input)
{
    size_t done = 0;
    while (done < sizeof *input) {
        long count = raw_read(STDIN_FILENO, (unsigned char *)input + done, sizeof *input - done);
        if (count == -EINTR)
            continue;
        if (count <= 0)
            return count == 0 && !done ? 0 : -1;
        done += (size_t)count;
    }
    return 1;
}

static int write_record(const struct observed *output)
{
    size_t done = 0;
    while (done < sizeof *output) {
        long count = raw_write(STDOUT_FILENO, (const unsigned char *)output + done, sizeof *output - done);
        if (count == -EINTR)
            continue;
        if (count <= 0)
            return 0;
        done += (size_t)count;
    }
    return 1;
}

static long movement(uint64_t value)
{
    return (long)(value & UINT64_C(0x7ffffffff));
}

static int observe_lseek(struct stimulus input, struct observed *output)
{
    int fd = memory_file(K_MFD_CLOEXEC);
    if (fd < 0 || raw_write(fd, "xyz", 3) != 3)
        return 90;
    int target = fd, whence = SEEK_SET, expected_error = TEST_ERRNO;
    long offset = movement(input.value), position = 3, expected = -1;
    switch (input.mode % 5) {
    case 0:
        expected = position = offset;
        break;
    case 1:
        whence = SEEK_CUR;
        offset = (long)(input.value % 257) - 128;
        if (offset >= -3)
            expected = position = offset + 3;
        else
            expected_error = EINVAL;
        break;
    case 2:
        whence = SEEK_END;
        expected = position = offset + 3;
        break;
    case 3:
        target = -1;
        expected_error = EBADF;
        break;
    case 4:
        whence = -1;
        expected_error = EINVAL;
        break;
    }
    errno = TEST_ERRNO;
    long result = lseek(target, offset, whence);
    int error = errno;
    long effect = raw_seek(fd, 0, SEEK_CUR);
    if (raw_close(fd) != 0)
        return 91;
    if (result != expected || error != expected_error || effect != position)
        return 11;
    *output = (struct observed){result, error, effect};
    return 0;
}

static int observe_dup(struct stimulus input, struct observed *output)
{
    int flags = (int)(input.value >> 63);
    int fd = memory_file(flags);
    if (fd < 0 || raw_write(fd, "xyz", 3) != 3)
        return 90;
    long lowest = raw_fcntl(fd, K_F_DUPFD, 0);
    if (lowest < 0 || raw_close((int)lowest) != 0)
        return 91;

    int invalid = input.mode % 4 == 0;
    errno = TEST_ERRNO;
    int result = dup(invalid ? -1 : fd);
    int error = errno;
    long expected = invalid ? 3 : movement(input.value);
    if (invalid) {
        if (result != -1 || error != EBADF)
            return 11;
    } else {
        if (result != lowest || error != TEST_ERRNO || raw_fcntl(result, K_F_GETFD, 0) != 0 ||
            raw_seek(result, 0, SEEK_CUR) != 3 || raw_seek(result, expected, SEEK_SET) != expected)
            return 12;
        if (raw_close(result))
            return 92;
    }
    long effect = raw_seek(fd, 0, SEEK_CUR);
    if (effect != expected || raw_fcntl(fd, K_F_GETFD, 0) != flags)
        return 13;
    if (raw_close(fd))
        return 93;
    *output = (struct observed){invalid ? -1 : 0, error, effect};
    return 0;
}

static int observe_dup2(struct stimulus input, struct observed *output)
{
    int flags = (int)(input.value >> 63);
    int fd = memory_file(flags), other = memory_file(K_MFD_CLOEXEC);
    if (fd < 0 || other < 0 || raw_write(fd, "xyz", 3) != 3 || raw_write(other, "q", 1) != 1)
        return 90;

    int source = fd, target = other, expected_error = TEST_ERRNO;
    int scenario = (int)(input.mode % 5);
    if (scenario == 1)
        target = fd;
    else if (scenario == 2)
        source = -1;
    else if (scenario == 3)
        target = -1;
    else if (scenario == 4 && raw_close(other))
        return 91;
    if (source < 0 || target < 0)
        expected_error = EBADF;

    errno = TEST_ERRNO;
    int result = dup2(source, target);
    int error = errno;
    if (result != (expected_error == EBADF ? -1 : target) || error != expected_error)
        return 11;

    long expected = 3;
    if (result >= 0) {
        int expected_flags = target == fd ? flags : 0;
        expected = movement(input.value);
        if (raw_fcntl(target, K_F_GETFD, 0) != expected_flags ||
            raw_seek(target, 0, SEEK_CUR) != 3 ||
            raw_seek(target, expected, SEEK_SET) != expected)
            return 12;
    }
    if (scenario >= 1 && scenario <= 3) {
        char original = 0;
        if (raw_fcntl(other, K_F_GETFD, 0) != K_FD_CLOEXEC ||
            raw_seek(other, 0, SEEK_CUR) != 1 || raw_seek(other, 0, SEEK_SET) != 0 ||
            raw_read(other, &original, 1) != 1 || original != 'q')
            return 13;
    }
    long effect = raw_seek(fd, 0, SEEK_CUR);
    if (effect != expected || raw_fcntl(fd, K_F_GETFD, 0) != flags)
        return 14;
    if (raw_close(other) || raw_close(fd))
        return 92;
    *output = (struct observed){result == -1 ? -1 : 0, error, effect};
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 94;
    int (*observe)(struct stimulus, struct observed *);
    if (same_text(argv[1], "lseek"))
        observe = observe_lseek;
    else if (same_text(argv[1], "dup"))
        observe = observe_dup;
    else if (same_text(argv[1], "dup2"))
        observe = observe_dup2;
    else
        return 95;

    struct stimulus input;
    int received;
    while ((received = read_record(&input)) == 1) {
        struct observed output;
        int status = observe(input, &output);
        if (status)
            return status;
        if (!write_record(&output))
            return 96;
    }
    return received < 0 ? 97 : 0;
}
