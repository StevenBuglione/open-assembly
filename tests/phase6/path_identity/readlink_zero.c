#include "../kernel_abi.h"

#include <stdint.h>

static int64_t bytes(const unsigned char buffer[3])
{
    return ((int64_t)buffer[0] << 16) | ((int64_t)buffer[1] << 8) | buffer[2];
}

int main(void)
{
    if (kernel_call(__NR_symlinkat, (long)"target", AT_FDCWD, (long)"zero-link", 0, 0, 0))
        return 90;
    unsigned char public_bytes[] = {'L', '!', 'R'}, raw_bytes[] = {'L', '!', 'R'};
    errno = TEST_ERRNO;
    long returned = readlink("zero-link", (char *)public_bytes + 1, 0);
    int error = errno;
    long raw = kernel_call(__NR_readlinkat, AT_FDCWD, (long)"zero-link", (long)(raw_bytes + 1), 0, 0, 0);
    if (raw_unlink("zero-link", 0))
        return 91;
    const int64_t unchanged = INT64_C(0x4c2152);
    if (raw != -EINVAL || bytes(raw_bytes) != unchanged)
        return 92;
#ifndef OA_PHASE6_HOST
    if (returned != -1 || error != EINVAL || bytes(public_bytes) != unchanged)
        return 41;
#endif
    int64_t observation[] = {returned, error, raw, bytes(public_bytes), bytes(raw_bytes)};
    return raw_write(STDOUT_FILENO, observation, sizeof observation) != (long)sizeof observation ? 93 : 0;
}
