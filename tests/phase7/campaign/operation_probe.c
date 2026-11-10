/* Binary32 wire-compatible probe with one direct math reference. */
#include <errno.h>
#include <fenv.h>
#include <float.h>
#include <math.h>
#include <stdint.h>
#include <unistd.h>

#include "../../phase5/fp_machine.h"

#if !defined(TEST_OPERATION_ID) || !defined(TEST_OPERATION_SYMBOL) || !defined(TEST_OPERATION_BINARY)
#error Select one declared binary32 operation
#endif

struct request {
    uint64_t low;
    uint16_t high, mode;
    uint32_t operation;
    uint64_t other_low;
    uint16_t other_high, seed;
    uint32_t reserved;
};

struct observation {
    uint64_t low;
    uint16_t high, flags;
    int32_t error;
};

union encoded {
    float number;
    uint32_t bits;
};

enum { TEST_ERRNO = 947, CHANGED_CONTROL = 0x8000, BATCH = 256 };
_Static_assert(sizeof(float) == 4 && FLT_MANT_DIG == 24, "x86 binary32 format");
_Static_assert(sizeof(struct request) == 32 && sizeof(struct observation) == 16, "wire format");

static int evaluate(const struct request *request, struct observation *result)
{
    if ((request->mode & ~0x0c00u) || request->operation != TEST_OPERATION_ID ||
        request->reserved || !request->seed || (request->seed & ~FE_ALL_EXCEPT))
        return 0;

    union encoded input = {.bits = (uint32_t)request->low}, output;
    struct machine_fenv original = observe();
    unsigned short control = (unsigned short)((original.control & ~0x0c00u) | request->mode);
    unsigned int mxcsr = (original.mxcsr & ~(0x6000u | 0x3fu)) |
                         ((unsigned int)request->mode << 3) | request->seed;
    install(control, mxcsr);
    volatile int *cell = __errno_location();
    *cell = TEST_ERRNO;
#if TEST_OPERATION_BINARY
    union encoded other = {.bits = (uint32_t)request->other_low};
    output.number = TEST_OPERATION_SYMBOL(input.number, other.number);
#else
    output.number = TEST_OPERATION_SYMBOL(input.number);
#endif
    struct machine_fenv current = observe();
    result->low = output.bits;
    result->high = 0;
    result->error = *cell;
    result->flags = (uint16_t)((current.status | current.mxcsr) & FE_ALL_EXCEPT);
    if (current.control != control || (current.mxcsr & ~0x3fu) != (mxcsr & ~0x3fu))
        result->flags |= CHANGED_CONTROL;
    install(original.control, original.mxcsr);
    return 1;
}

static ssize_t read_batch(unsigned char *destination, size_t capacity)
{
    size_t count = 0;
    while (count < capacity) {
        ssize_t got = read(STDIN_FILENO, destination + count, capacity - count);
        if (got < 0 && errno == EINTR)
            continue;
        if (got < 0)
            return -1;
        if (!got)
            break;
        count += (size_t)got;
    }
    return (ssize_t)count;
}

static int write_all(const unsigned char *source, size_t size)
{
    size_t count = 0;
    while (count < size) {
        ssize_t got = write(STDOUT_FILENO, source + count, size - count);
        if (got < 0 && errno == EINTR)
            continue;
        if (got <= 0)
            return 0;
        count += (size_t)got;
    }
    return 1;
}

int main(void)
{
    struct request requests[BATCH];
    struct observation results[BATCH];
    for (;;) {
        ssize_t bytes = read_batch((unsigned char *)requests, sizeof requests);
        if (bytes < 0 || bytes % (ssize_t)sizeof requests[0])
            return 2;
        if (!bytes)
            return 0;
        size_t count = (size_t)bytes / sizeof requests[0];
        for (size_t index = 0; index < count; ++index) {
            if (!evaluate(&requests[index], &results[index]))
                return 3;
        }
        if (!write_all((const unsigned char *)results, count * sizeof results[0]))
            return 4;
    }
}
