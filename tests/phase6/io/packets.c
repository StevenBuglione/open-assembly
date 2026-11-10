#include "fixture.h"

struct request { uint64_t mode, seed; };
struct response { int64_t result, error, effect; };
_Static_assert(sizeof(struct request) == 16 && sizeof(struct response) == 24, "LP64 packet ABI");

static int transfer(void *memory, size_t length, int writing)
{
    size_t done = 0;
    while (done < length) {
        unsigned char *bytes = (unsigned char *)memory + done;
        long count = writing ? raw_write(STDOUT_FILENO, bytes, length - done) :
                               raw_read(STDIN_FILENO, bytes, length - done);
        if (count == -EINTR)
            continue;
        if (count <= 0)
            return count == 0 && !done && !writing ? 0 : -1;
        done += (size_t)count;
    }
    return 1;
}

static int close_pair(int first, int second)
{
    return raw_close(first) == 0 && raw_close(second) == 0;
}

static int observe_read(struct request input, struct response *response, int positional)
{
    const unsigned char fixture[] = {'x', 'y', 'z'};
    const long file_base = positional ? (long)((UINT64_C(1) << 34) + (input.seed >> 32)) : 0;
    int fd = memory_file();
    int pipefd[2] = {-1, -1};
    if (fd < 0 || raw_pwrite(fd, fixture, sizeof fixture, file_base) != sizeof fixture)
        return 90;
    unsigned mode = (unsigned)(input.mode % 6);
    size_t length = (input.seed & 7) + 1;
    int source = fd, error = TEST_ERRNO;
    long relative = mode == 1 ? 3 : mode == 5 ? 2 : 0;
    long position = positional ? 13 : relative;
    long requested = file_base + relative;
    if (raw_seek(fd, position, SEEK_SET) != position)
        return 91;
    if (mode == 2)
        length = 0;
    if (mode == 3) {
        source = -1;
        error = EBADF;
    }
    if (mode == 4 && positional) {
        if (input.seed & 16) {
            if (raw_pipe(pipefd))
                return 92;
            source = pipefd[0];
            error = ESPIPE;
        } else {
            requested = -1;
            error = EINVAL;
        }
    }
    size_t available = (size_t)(3 - relative);
    long count = error == TEST_ERRNO ? (long)(length < available ? length : available) : -1;
    unsigned char bytes[9];
    for (size_t i = 0; i < sizeof bytes; ++i)
        bytes[i] = 0xa5;
    errno = TEST_ERRNO;
    long result = positional ? pread(source, bytes, length, requested) : read(source, bytes, length);
    int observed_error = errno;
    long after = raw_seek(fd, 0, SEEK_CUR);
    if (raw_close(fd) || (pipefd[0] >= 0 && !close_pair(pipefd[0], pipefd[1])))
        return 93;
    if (result != count || observed_error != error || after != position + (positional || count < 0 ? 0 : count))
        return 11;
    uint64_t data = 0;
    for (size_t i = 0; i < sizeof bytes; ++i) {
        unsigned char want = count > 0 && i < (size_t)count ? fixture[relative + i] : 0xa5;
        if (bytes[i] != want)
            return 12;
        if (count > 0 && i < (size_t)count)
            data |= (uint64_t)bytes[i] << (8 * i);
    }
    *response = (struct response){result, observed_error, (int64_t)(data | (uint64_t)after << 32)};
    return 0;
}

static int observe_write(struct request input, struct response *response, int positional)
{
    const unsigned char fixture[] = {'x', 'y', 'z'};
    int fd = memory_file(), pipefd[2] = {-1, -1};
    if (fd < 0 || raw_pwrite(fd, fixture, sizeof fixture, 0) != sizeof fixture)
        return 90;
    unsigned mode = (unsigned)(input.mode % 6);
    size_t length = (input.seed & 7) + 1;
    int target = fd, error = TEST_ERRNO;
    long position = positional ? 13 : mode == 1 ? 3 : 0;
    long requested = positional && mode == 0 ? (long)((UINT64_C(1) << 34) + (input.seed >> 32)) :
                     positional ? (long)(input.seed >> 8 & 31) : position;
    if (raw_seek(fd, position, SEEK_SET) != position)
        return 91;
    if (mode == 2)
        length = 0;
    if (mode == 3) {
        target = -1;
        error = EBADF;
    }
    if (mode == 4 && positional) {
        if (input.seed & 16) {
            if (raw_pipe(pipefd))
                return 92;
            target = pipefd[1];
            error = ESPIPE;
        } else {
            requested = -1;
            error = EINVAL;
        }
    }
    unsigned char payload[8];
    for (size_t i = 0; i < sizeof payload; ++i)
        payload[i] = (unsigned char)(input.seed >> (i * 8)) ^ (unsigned char)(0x89 + i);
    errno = TEST_ERRNO;
    long result = positional ? pwrite(target, payload, length, requested) : write(target, payload, length);
    int observed_error = errno;
    long after = raw_seek(fd, 0, SEEK_CUR);
    long size = raw_seek(fd, 0, SEEK_END);
    long count = error == TEST_ERRNO ? (long)length : -1;
    long expected_size = count > 0 && requested + count > 3 ? requested + count : 3;
    if (result != count || observed_error != error || size != expected_size ||
        after != position + (positional || count < 0 ? 0 : count))
        return 11;
    if (count > 0) {
        unsigned char recorded[8];
        if (raw_pread(fd, recorded, length, requested) != count)
            return 93;
        for (size_t i = 0; i < length; ++i)
            if (recorded[i] != payload[i])
                return 12;
    }
    unsigned char leading[3];
    if (raw_pread(fd, leading, sizeof leading, 0) != sizeof leading)
        return 94;
    for (long i = 0; i < 3; ++i) {
        unsigned char expected = count > 0 && i >= requested && i < requested + count ?
                                 payload[i - requested] : fixture[i];
        if (leading[i] != expected)
            return 13;
    }
    if (raw_close(fd) || (pipefd[0] >= 0 && !close_pair(pipefd[0], pipefd[1])))
        return 95;
    *response = (struct response){result, observed_error, size};
    return 0;
}

static int observe_close(struct request input, struct response *response)
{
    int first = memory_file(), second = memory_file();
    if (first < 0 || second < 0)
        return 90;
    unsigned mode = (unsigned)(input.mode % 4);
    int selected = mode == 0 || mode == 3 ? first : mode == 1 ? second : -1;
    if (mode == 3 && raw_close(first))
        return 91;
    errno = TEST_ERRNO;
    int result = close(selected);
    int observed_error = errno;
    int first_live = mode == 1 || mode == 2, second_live = mode != 1;
    if (result != (mode < 2 ? 0 : -1) || observed_error != (mode < 2 ? TEST_ERRNO : EBADF) ||
        raw_fcntl(first, K_F_GETFD, 0) != (first_live ? K_FD_CLOEXEC : -EBADF) ||
        raw_fcntl(second, K_F_GETFD, 0) != (second_live ? K_FD_CLOEXEC : -EBADF))
        return 11;
    if ((first_live && raw_close(first)) || (second_live && raw_close(second)))
        return 92;
    *response = (struct response){result, observed_error, first_live + 2 * second_live};
    return 0;
}

int main(int argc, char **argv)
{
    static const char *const modes[] = {"read", "write", "close", "pread", "pwrite"};
    if (argc != 2)
        return 96;
    unsigned operation = 0;
    while (operation < sizeof modes / sizeof *modes && !same_text(argv[1], modes[operation]))
        ++operation;
    if (operation == sizeof modes / sizeof *modes)
        return 97;
    struct request input;
    int received;
    while ((received = transfer(&input, sizeof input, 0)) == 1) {
        struct response result;
        int status;
        if (operation == 0 || operation == 3)
            status = observe_read(input, &result, operation == 3);
        else if (operation == 1 || operation == 4)
            status = observe_write(input, &result, operation == 4);
        else
            status = observe_close(input, &result);
        if (status)
            return status;
        if (transfer(&result, sizeof result, 1) != 1)
            return 98;
    }
    return received < 0 ? 99 : 0;
}
