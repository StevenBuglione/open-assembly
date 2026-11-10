#ifndef OA_PIPE_IDENTITY_ENDPOINT_H
#define OA_PIPE_IDENTITY_ENDPOINT_H

#include "../kernel_abi.h"
#include <stdint.h>

enum { SENTINEL_LEFT = -0x34561, SENTINEL_RIGHT = -0x45671 };

struct endpoint_observation { unsigned order, flags; };

static inline struct endpoint_observation endpoints(const int descriptors[2])
{
    long read_status = raw_fcntl(descriptors[0], K_F_GETFL, 0);
    long write_status = raw_fcntl(descriptors[1], K_F_GETFL, 0);
    long read_descriptor = raw_fcntl(descriptors[0], K_F_GETFD, 0);
    long write_descriptor = raw_fcntl(descriptors[1], K_F_GETFD, 0);
    struct endpoint_observation result = {0, 0};
    if (read_status < 0 || write_status < 0 || read_descriptor < 0 || write_descriptor < 0)
        return result;
    result.order = ((read_status & O_ACCMODE) == O_RDONLY) |
                   (((write_status & O_ACCMODE) == O_WRONLY) << 1) |
                   ((descriptors[0] != descriptors[1]) << 2);
    result.flags = (read_descriptor & K_FD_CLOEXEC ? 1u : 0u) |
                   (write_descriptor & K_FD_CLOEXEC ? 2u : 0u) |
                   (read_status & O_NONBLOCK ? 4u : 0u) |
                   (write_status & O_NONBLOCK ? 8u : 0u);
    return result;
}

#endif
