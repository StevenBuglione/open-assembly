#include <complex.h>
#include <errno.h>
#include <fenv.h>
#include <float.h>
#include <stdint.h>
#include <stdio.h>

#include "../../phase5/fp_machine.h"

/* Some host headers provide extraction macros alongside their public functions. */
#undef crealf
#undef creal
#undef creall
#undef cimagf
#undef cimag
#undef cimagl

#define JOIN_(left, right) left##right
#define JOIN(left, right) JOIN_(left, right)

#if TEST_FORMAT == 32
typedef float scalar;
typedef float _Complex pair;
#define MATH(name) JOIN(name, f)
#elif TEST_FORMAT == 64
typedef double scalar;
typedef double _Complex pair;
#define MATH(name) name
#elif TEST_FORMAT == 80
typedef long double scalar;
typedef long double _Complex pair;
#define MATH(name) JOIN(name, l)
#else
#error TEST_FORMAT must select 32, 64 or 80
#endif

_Static_assert(FLT_MANT_DIG == 24 && DBL_MANT_DIG == 53 && LDBL_MANT_DIG == 64 &&
               sizeof(long double) == 16, "x86 floating formats");
_Static_assert(sizeof(pair) == 2 * sizeof(scalar), "complex object representation");

enum operation {
#define SCALAR(name) op_##name,
#define PAIR(name) op_##name,
#define BINARY(name) op_##name,
#include "operations.def"
#undef SCALAR
#undef PAIR
#undef BINARY
    op_count
};
enum { TEST_ERRNO = 947, CHANGED_CONTROL = 0x8000, CHANGED_X87_DEPTH = 0x4000, BATCH = 256 };

struct request {
    uint64_t real_low;
    uint16_t real_high, mode;
    uint32_t operation;
    uint64_t imag_low;
    uint16_t imag_high, seed;
    uint32_t reserved;
    uint64_t exponent_real_low, exponent_imag_low;
    uint16_t exponent_real_high, exponent_imag_high;
    uint32_t reserved_exponent;
};

struct observation {
    uint64_t real_low;
    uint16_t real_high, flags;
    int32_t error;
    uint64_t imag_low;
    uint16_t imag_high;
    unsigned char reserved[6];
};

_Static_assert(sizeof(struct request) == 56 && sizeof(struct observation) == 32, "wire layout");

union complex_bits {
    pair value;
    unsigned char bytes[sizeof(pair)];
};

union scalar_bits {
    scalar value;
    unsigned char bytes[sizeof(scalar)];
};

static void store(unsigned char *bytes, uint64_t low, uint16_t high)
{
    for (size_t i = 0; i < sizeof(scalar) && i < 8; ++i)
        bytes[i] = (unsigned char)(low >> (i * 8));
#if TEST_FORMAT == 80
    bytes[8] = (unsigned char)high;
    bytes[9] = (unsigned char)(high >> 8);
#else
    (void)high;
#endif
}

static void load(const unsigned char *bytes, uint64_t *low, uint16_t *high)
{
    *low = 0;
    *high = 0;
    for (size_t i = 0; i < sizeof(scalar) && i < 8; ++i)
        *low |= (uint64_t)bytes[i] << (i * 8);
#if TEST_FORMAT == 80
    *high = (uint16_t)(bytes[8] | ((uint16_t)bytes[9] << 8));
#endif
}

static int evaluate(const struct request *request, struct observation *result)
{
    if ((request->mode & ~0xc00u) || request->operation >= op_count ||
        request->reserved || request->reserved_exponent || !request->seed ||
        (request->seed & ~FE_ALL_EXCEPT) ||
        (request->operation != op_cpow &&
         (request->exponent_real_low || request->exponent_imag_low ||
          request->exponent_real_high || request->exponent_imag_high)))
        return 0;

    union complex_bits input = {.bytes = {0}}, exponent = {.bytes = {0}}, output = {.bytes = {0}};
    union scalar_bits part = {.bytes = {0}};
    store(input.bytes, request->real_low, request->real_high);
    store(input.bytes + sizeof(scalar), request->imag_low, request->imag_high);
    store(exponent.bytes, request->exponent_real_low, request->exponent_real_high);
    store(exponent.bytes + sizeof(scalar), request->exponent_imag_low, request->exponent_imag_high);

    struct machine_fenv original = observe();
    unsigned short control = (unsigned short)((original.control & ~0x0c00u) | request->mode);
    unsigned int mxcsr = (original.mxcsr & ~(0x6000u | 0x3fu)) |
                         ((unsigned int)request->mode << 3) | request->seed;
    install(control, mxcsr);
    volatile int *cell = __errno_location();
    *cell = TEST_ERRNO;

    *result = (struct observation){0};
    switch (request->operation) {
#define SCALAR(name) \
    case op_##name: \
        part.value = MATH(name)(input.value); \
        load(part.bytes, &result->real_low, &result->real_high); \
        break;
#define PAIR(name) \
    case op_##name: \
        output.value = MATH(name)(input.value); \
        load(output.bytes, &result->real_low, &result->real_high); \
        load(output.bytes + sizeof(scalar), &result->imag_low, &result->imag_high); \
        break;
#define BINARY(name) \
    case op_##name: \
        output.value = MATH(name)(input.value, exponent.value); \
        load(output.bytes, &result->real_low, &result->real_high); \
        load(output.bytes + sizeof(scalar), &result->imag_low, &result->imag_high); \
        break;
#include "operations.def"
#undef SCALAR
#undef PAIR
#undef BINARY
    }

    __asm__ volatile("" : : "m"(*result) : "memory");
    struct machine_fenv current = observe();
    result->error = *cell;
    result->flags = (uint16_t)((current.status | current.mxcsr) & FE_ALL_EXCEPT);
    if (current.control != control || (current.mxcsr & ~0x3fu) != (mxcsr & ~0x3fu))
        result->flags |= CHANGED_CONTROL;
    if ((current.status ^ original.status) & 0x3800u)
        result->flags |= CHANGED_X87_DEPTH;
    install(original.control, original.mxcsr);
    return 1;
}

int main(void)
{
    struct request requests[BATCH];
    struct observation results[BATCH];
    for (;;) {
        size_t bytes = fread(requests, 1, sizeof requests, stdin);
        if (ferror(stdin) || bytes % sizeof requests[0])
            return 2;
        if (!bytes)
            return fflush(stdout) != 0;
        size_t count = bytes / sizeof requests[0];
        for (size_t i = 0; i < count; ++i) {
            if (!evaluate(&requests[i], &results[i]))
                return 3;
        }
        if (fwrite(results, sizeof results[0], count, stdout) != count)
            return 4;
    }
}
