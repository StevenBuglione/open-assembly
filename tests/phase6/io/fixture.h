#ifndef OA_PHASE6_IO_FIXTURE_H
#define OA_PHASE6_IO_FIXTURE_H

#include "../kernel_abi.h"
#include <stdint.h>

enum { K_MEMFD = 319, K_PREAD = 17, K_PWRITE = 18, K_PIPE = 22, K_FSTATFS = 138, K_PWRITEV2 = 328 };
enum { K_F_SETFL = 4, K_RWF_NOAPPEND = 0x20 };

static inline int memory_file(void)
{
    return (int)kernel_call(K_MEMFD, (long)"oa-io-fixture", 1, 0, 0, 0, 0);
}

static inline long raw_pread(int fd, void *bytes, size_t length, long offset)
{
    return kernel_call(K_PREAD, fd, (long)bytes, length, offset, 0, 0);
}

static inline long raw_pwrite(int fd, const void *bytes, size_t length, long offset)
{
    return kernel_call(K_PWRITE, fd, (long)bytes, length, offset, 0, 0);
}

static inline long raw_pipe(int pair[2])
{
    return kernel_call(K_PIPE, (long)pair, 0, 0, 0, 0, 0);
}

#endif
