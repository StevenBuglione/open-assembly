#include <errno.h>
#include <limits.h>

#include "linux_abi.h"

int main(void)
{
    static const long successful[] = {LONG_MIN, -4096, 0, 1, 0x1234567800000000L, LONG_MAX};
    static const int errors[] = {4095, EBADF, 1};
    for (unsigned int i = 0; i < sizeof successful / sizeof successful[0]; ++i) {
        errno = 901;
        if (__al_syscall_result(successful[i]) != successful[i] || errno != 901)
            return 20 + (int)i;
    }
    for (unsigned int i = 0; i < sizeof errors / sizeof errors[0]; ++i) {
        errno = 902;
        if (__al_syscall_result(-errors[i]) != -1 || errno != errors[i])
            return 30 + (int)i;
    }
    return 0;
}
