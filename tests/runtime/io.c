#include <errno.h>
#include <linux/fcntl.h>
#include <linux/mman.h>
#include <stdint.h>
#include <unistd.h>

#include "linux_abi.h"

static int check_read(int reader, int writer)
{
    static const char payload[] = "abc";
    char bytes[8] = {'.', '.', '.', '.', '.', '.', '.', '.'};
    if (__al_syscall(__NR_write, writer, (long)payload, 3, 0, 0, 0) != 3)
        return 20;

    errno = 121;
    if (read(reader, bytes, 0) != 0 || errno != 121 || bytes[0] != '.')
        return 21;
    if (read(reader, bytes, sizeof bytes) != 3 || errno != 121)
        return 22;
    for (unsigned int i = 0; i < sizeof bytes; ++i)
        if (bytes[i] != (i < 3 ? payload[i] : '.'))
            return 23;

    if (read(reader, bytes, sizeof bytes) != -1 || errno != EAGAIN)
        return 24;
    if (__al_syscall(__NR_close, writer, 0, 0, 0, 0, 0) != 0)
        return 25;
    errno = 122;
    if (read(reader, bytes, sizeof bytes) != 0 || errno != 122)
        return 26;

    if (__al_syscall(__NR_close, reader, 0, 0, 0, 0, 0) != 0)
        return 27;
    if (read(reader, bytes, sizeof bytes) != -1 || errno != EBADF)
        return 28;
    return 0;
}

static int check_write(int reader, int writer)
{
    long capacity = __al_syscall(__NR_fcntl, writer, F_GETPIPE_SZ, 0, 0, 0, 0);
    if (capacity <= 0)
        return 30;
    long mapping = __al_syscall(__NR_mmap, 0, capacity + 1, PROT_READ | PROT_WRITE,
                                MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if ((unsigned long)mapping >= (unsigned long)-4095)
        return 31;
    char *payload = (char *)mapping;
    for (long i = 0; i <= capacity; ++i)
        payload[i] = (char)('A' + (i % 26));

    errno = 123;
    if (write(writer, payload, 0) != 0 || errno != 123)
        return 32;
    if (write(writer, payload, (size_t)capacity + 1) != capacity || errno != 123)
        return 33;
    if (write(writer, payload, 1) != -1 || errno != EAGAIN)
        return 34;

    long checked = 0;
    char bytes[512];
    while (checked < capacity) {
        long count = __al_syscall(__NR_read, reader, (long)bytes, sizeof bytes, 0, 0, 0);
        if (count <= 0 || count > capacity - checked)
            return 35;
        for (long i = 0; i < count; ++i)
            if (bytes[i] != payload[checked + i])
                return 36;
        checked += count;
    }
    if (__al_syscall(__NR_close, writer, 0, 0, 0, 0, 0) != 0)
        return 37;
    if (write(writer, payload, 1) != -1 || errno != EBADF)
        return 38;
    if (__al_syscall(__NR_munmap, mapping, capacity + 1, 0, 0, 0, 0) != 0)
        return 39;
    return 0;
}

static int check_close(int reader)
{
    errno = 124;
    if (close(reader) != 0 || errno != 124)
        return 41;
    char byte;
    if (__al_syscall(__NR_read, reader, (long)&byte, 1, 0, 0, 0) != -EBADF)
        return 42;
    if (close(reader) != -1 || errno != EBADF)
        return 43;
    errno = 125;
    if (close(-1) != -1 || errno != EBADF)
        return 44;
    return 0;
}

int main(int argc, char **argv)
{
    int ends[2];
    if (argc != 2 || __al_syscall(__NR_pipe2, (long)ends, O_NONBLOCK, 0, 0, 0, 0) != 0)
        return 10;
    switch (argv[1][0]) {
    case 'r': return check_read(ends[0], ends[1]);
    case 'w': return check_write(ends[0], ends[1]);
    case 'c': return check_close(ends[0]);
    default: return 11;
    }
}
