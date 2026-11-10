#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <unistd.h>

extern unsigned phase2_abi_probe(uintptr_t, const uint64_t[6]);
extern int fcntl_integer_thunk(int, int, ...);

int main(void)
{
    int pipes[2];
    if (pipe(pipes))
        return 90;
    uint64_t args[6] = {UINT64_C(0xa3749ff100000000) | (uint32_t)pipes[0],
                        UINT64_C(0x815ab97500000000) | F_SETFD,
                        UINT64_C(0x9fbc21ec00000000) | FD_CLOEXEC};
    errno = EDOM;
    if (phase2_abi_probe((uintptr_t)fcntl_integer_thunk, args) ||
        fcntl(pipes[0], F_GETFD) != FD_CLOEXEC || errno != EDOM)
        return 11;
    args[0] = UINT64_C(0x40239abcffffffff);
    args[1] = UINT64_C(0xabf47e8a00000000) | F_GETFD;
    errno = EDOM;
    if (phase2_abi_probe((uintptr_t)fcntl_integer_thunk, args) || errno != EBADF)
        return 12;
    return close(pipes[0]) || close(pipes[1]) ? 90 : 0;
}
