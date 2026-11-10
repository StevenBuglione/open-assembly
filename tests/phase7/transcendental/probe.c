#include <errno.h>
#include <fenv.h>
#include <float.h>
#include <math.h>
#include <stdint.h>
#include <unistd.h>

#include "../../phase5/fp_machine.h"

#define JOIN_(left, right) left##right
#define JOIN(left, right) JOIN_(left, right)

#if TEST_FORMAT == 32
typedef float scalar;
#define MATH(name) JOIN(name, f)
#elif TEST_FORMAT == 64
typedef double scalar;
#define MATH(name) name
#elif TEST_FORMAT == 80
typedef long double scalar;
#define MATH(name) JOIN(name, l)
#else
#error TEST_FORMAT must select 32, 64 or 80
#endif

_Static_assert(FLT_MANT_DIG == 24 && DBL_MANT_DIG == 53 && LDBL_MANT_DIG == 64 &&
               sizeof(long double) == 16, "x86 floating formats");

enum operation {
#define OP(name) op_##name,
#define OP2(name) OP(name)
#include "operations.def"
#undef OP
#undef OP2
    operation_count
};

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
    scalar number;
    struct {
        uint64_t low;
        uint16_t high;
        unsigned char reserved[6];
    } bits;
};

enum { TEST_ERRNO = 947, CHANGED_CONTROL = 0x8000, BATCH = 256 };
_Static_assert(sizeof(struct request) == 32 && sizeof(struct observation) == 16, "wire format");

static int evaluate(const struct request *request, struct observation *result)
{
    if ((request->mode & ~0x0c00u) || request->operation >= operation_count ||
        request->reserved || !request->seed || (request->seed & ~FE_ALL_EXCEPT))
        return 0;
    union encoded input = {.bits = {.low = request->low, .high = request->high}};
    union encoded other = {.bits = {.low = request->other_low, .high = request->other_high}};
    union encoded output = {.bits = {0}};
    struct machine_fenv original = observe();
    unsigned short control = (unsigned short)((original.control & ~0x0c00u) | request->mode);
    unsigned int mxcsr = (original.mxcsr & ~(0x6000u | 0x3fu)) |
                         ((unsigned int)request->mode << 3) | request->seed;
    install(control, mxcsr);
    volatile int *cell = __errno_location();
    *cell = TEST_ERRNO;
    switch ((enum operation)request->operation) {
#define OP(name) case op_##name: output.number = MATH(name)(input.number); break;
#define OP2(name) case op_##name: output.number = MATH(name)(input.number, other.number); break;
#include "operations.def"
#undef OP
#undef OP2
    case operation_count: break;
    }

    struct machine_fenv current = observe();
    result->low = output.bits.low;
    result->high = output.bits.high;
    result->error = *cell;
    result->flags = (uint16_t)((current.status | current.mxcsr) & FE_ALL_EXCEPT);
    if (current.control != control || (current.mxcsr & ~0x3fu) != (mxcsr & ~0x3fu))
        result->flags |= CHANGED_CONTROL;
    install(original.control, original.mxcsr);
    return 1;
}

static ssize_t read_batch(void *storage, size_t capacity)
{
    unsigned char *destination = storage;
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

static int write_all(const void *storage, size_t size)
{
    const unsigned char *source = storage;
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
        ssize_t bytes = read_batch(requests, sizeof requests);
        if (bytes < 0 || bytes % (ssize_t)sizeof requests[0])
            return 2;
        if (!bytes)
            return 0;
        size_t count = (size_t)bytes / sizeof requests[0];
        for (size_t i = 0; i < count; ++i) {
            if (!evaluate(&requests[i], &results[i]))
                return 3;
        }
        if (!write_all(results, count * sizeof results[0]))
            return 4;
    }
}
