#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

struct result { int status, error, followup; };
_Static_assert(sizeof(struct result) == 12, "three little-endian signed fields");

static int next_word(uint32_t *word)
{
    unsigned char *p = (void *)word;
    size_t offset = 0;
    while (offset < sizeof *word) {
        ssize_t got = read(STDIN_FILENO, p + offset, sizeof *word - offset);
        if (!got)
            return offset ? -1 : 0;
        if (got < 0) {
            if (errno != EINTR)
                return -1;
            continue;
        }
        offset += (size_t)got;
    }
    return 1;
}

static int write_result(const struct result *result)
{
    const unsigned char *p = (const void *)result;
    size_t offset = 0;
    while (offset < sizeof *result) {
        ssize_t count = write(STDOUT_FILENO, p + offset, sizeof *result - offset);
        if (count <= 0) {
            if (count < 0 && errno == EINTR)
                continue;
            return 0;
        }
        offset += (size_t)count;
    }
    return 1;
}

static struct result one(int *pipefds, int file, uint32_t word)
{
    int fd = pipefds[(word >> 4) & 1];
    int argument = (word & 0x20) ? FD_CLOEXEC : 0;
    int status = -99, followup = -99, error;
    const int mask = O_ACCMODE | O_NONBLOCK | O_APPEND;
    errno = EDOM;
    switch (word & 15) {
    case 0:
        status = fcntl(fd, F_GETFD);
        break;
    case 1:
        status = fcntl(fd, F_SETFD, argument);
        error = errno;
        followup = fcntl(fd, F_GETFD);
        return (struct result){status, error, followup};
    case 2:
        status = fcntl(fd, F_GETFL);
        if (status >= 0)
            status &= mask;
        break;
    case 3:
        argument = ((word & 0x20) ? O_NONBLOCK : 0) | ((word & 0x40) ? O_APPEND : 0);
        status = fcntl(fd, F_SETFL, argument);
        error = errno;
        followup = fcntl(fd, F_GETFL) & mask;
        return (struct result){status, error, followup};
    case 4:
    case 5:
        argument = (int)((word >> 5) % 113) + 16;
        status = fcntl(fd, (word & 1) ? F_DUPFD_CLOEXEC : F_DUPFD, argument);
        error = errno;
        if (status >= 0) {
            followup = fcntl(status, F_GETFD);
            if (close(status))
                followup = -98;
        }
        return (struct result){status, error, followup};
    case 6:
        status = fcntl(-1, F_GETFD);
        break;
    case 7:
        status = fcntl(fd, F_DUPFD, -(int)((word >> 5) % 4096) - 1);
        break;
    case 8:
    case 9: {
        struct flock lock = {.l_type = F_RDLCK, .l_whence = SEEK_SET,
                             .l_start = (off_t)word << 21, .l_len = (word >> 13) + 1};
        status = fcntl(file, (word & 1) ? F_OFD_GETLK : F_GETLK, &lock);
        error = errno;
        return (struct result){status, error, lock.l_type};
    }
    case 10:
    case 11: {
        struct flock lock = {.l_type = F_WRLCK, .l_whence = SEEK_SET,
                             .l_start = (off_t)word << 19, .l_len = (word >> 12) + 1};
        int command = (word & 1) ? F_OFD_SETLK : F_SETLK;
        status = fcntl(file, command, &lock);
        error = errno;
        lock.l_type = F_UNLCK;
        followup = fcntl(file, command, &lock);
        return (struct result){status, error, followup};
    }
    case 12:
        status = fcntl(fd, F_GETPIPE_SZ);
        if (status > 0)
            status = 1;
        break;
    case 13:
        status = fcntl(fd, F_SETPIPE_SZ, (int)((word >> 5) & 511));
        if (status > 0)
            status = 1;
        break;
    case 14:
        status = fcntl(fd, F_SETOWN, 0);
        error = errno;
        followup = fcntl(fd, F_GETOWN);
        return (struct result){status, error, followup};
    case 15:
        status = fcntl(-1, F_SETFL, argument);
        break;
    }
    return (struct result){status, errno, followup};
}

int main(void)
{
    char name[] = "fcntl-fuzz-XXXXXX";
    int file = mkstemp(name);
    int pipefds[2];
    if (file < 0 || unlink(name) || pipe(pipefds))
        return 90;
    uint32_t word;
    int status;
    while ((status = next_word(&word)) == 1) {
        struct result result = one(pipefds, file, word);
        if (!write_result(&result))
            return 91;
    }
    return status || close(pipefds[0]) || close(pipefds[1]) || close(file) ? 92 : 0;
}
