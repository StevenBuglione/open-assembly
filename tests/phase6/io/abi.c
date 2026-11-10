#include "fixture.h"

extern unsigned phase2_abi_probe(uintptr_t target, const uint64_t arguments[6]);

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    int fd = memory_file();
    if (fd < 0 || raw_pwrite(fd, "abcdef", 6, 0) != 6)
        return 91;
    unsigned char data[8] = {0xa5, 1, 2, 3, 4, 5, 6, 7};
    uint64_t args[6] = {UINT64_C(0x8961bb4c00000000) | (unsigned)fd,
                        (uintptr_t)data, 3, UINT64_C(0x200000001)};
    uintptr_t target;
    if (same_text(argv[1], "read"))
        target = (uintptr_t)read;
    else if (same_text(argv[1], "write"))
        target = (uintptr_t)write;
    else if (same_text(argv[1], "close"))
        target = (uintptr_t)close;
    else if (same_text(argv[1], "pread"))
        target = (uintptr_t)pread;
    else if (same_text(argv[1], "pwrite"))
        target = (uintptr_t)pwrite;
    else
        return 92;

    errno = TEST_ERRNO;
    unsigned changed = phase2_abi_probe(target, args);
    int error = errno;
    long state = raw_fcntl(fd, K_F_GETFD, 0);
    if (state >= 0 && raw_close(fd))
        return 93;
    if (changed)
        return 11;
    if (error != TEST_ERRNO || (target == (uintptr_t)close ? state != -EBADF : state != K_FD_CLOEXEC))
        return 12;
    return 0;
}
