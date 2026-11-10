#include <errno.h>
#include <fenv.h>
#include <float.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

#include "../phase5/fp_machine.h"

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
#include "operations.def"
#undef OP
    operation_count
};
enum { TEST_ERRNO = 947, SEED_FLAGS = FE_DIVBYZERO, QUIET_NAN = 1 };

struct encoding {
    uint64_t low;
    uint16_t high;
    unsigned char reserved[6];
};

union value {
    scalar number;
    struct encoding encoded;
};

struct packet {
    uint16_t operation, mode, flags, error;
    int64_t parameter, integer;
    uint32_t policy, reserved;
    struct encoding x, y, z, wanted, secondary;
};
_Static_assert(sizeof(struct packet) == 112, "packet wire layout");

static int same_bits(struct encoding left, struct encoding right)
{
    return left.low == right.low && left.high == right.high;
}

static int quiet_nan(struct encoding value)
{
#if TEST_FORMAT == 32
    return (value.low & UINT32_C(0x7fc00000)) == UINT32_C(0x7fc00000);
#elif TEST_FORMAT == 64
    return (value.low & UINT64_C(0x7ff8000000000000)) == UINT64_C(0x7ff8000000000000);
#else
    return (value.high & 0x7fff) == 0x7fff &&
           (value.low & UINT64_C(0xc000000000000000)) == UINT64_C(0xc000000000000000);
#endif
}

static int class_bits(scalar value)
{
    int category = fpclassify(value);
    switch (category) {
    case FP_NAN: category = 0; break;
    case FP_INFINITE: category = 1; break;
    case FP_ZERO: category = 2; break;
    case FP_SUBNORMAL: category = 3; break;
    case FP_NORMAL: category = 4; break;
    default: return -1;
    }
    return category | ((!!signbit(value)) << 3) | ((!!isfinite(value)) << 4) |
           ((!!isinf(value)) << 5) | ((!!isnan(value)) << 6) | ((!!isnormal(value)) << 7);
}

static int compare_bits(scalar x, scalar y)
{
    return (!!isgreater(x, y)) | ((!!isgreaterequal(x, y)) << 1) |
           ((!!isless(x, y)) << 2) | ((!!islessequal(x, y)) << 3) |
           ((!!islessgreater(x, y)) << 4) | ((!!isunordered(x, y)) << 5);
}

static int check(const struct packet *test, int bits_only)
{
    union value x = {.encoded = test->x}, y = {.encoded = test->y}, z = {.encoded = test->z};
    union value result = {.encoded = {0}}, auxiliary = {.encoded = {0}};
    union { long double number; struct encoding encoded; } toward = {.encoded = test->y};
    int out = 0x41424344;
    int64_t integer = 0;
    static const char *const tags[] = {"", "12345", "tag_with_underscore", "tag-punctuation!"};
    if (test->operation >= operation_count || (test->mode & ~0x0c00u) ||
        test->policy > QUIET_NAN || test->reserved ||
        (test->operation == op_nan && (uint64_t)test->parameter >= sizeof tags / sizeof tags[0]))
        return 10;

    struct machine_fenv original = observe();
    unsigned short control = (unsigned short)((original.control & ~0x0c00u) | test->mode);
    unsigned int seed = test->flags & FE_DIVBYZERO ? FE_INVALID : SEED_FLAGS;
    unsigned int mxcsr = (original.mxcsr & ~(0x6000u | 0x3fu)) |
                         ((unsigned int)test->mode << 3) | seed;
    install(control, mxcsr);
    volatile int *cell = __errno_location();
    *cell = TEST_ERRNO;
    switch ((enum operation)test->operation) {
#define UNARY(name) case op_##name: result.number = MATH(name)(x.number); break
#define BINARY(name) case op_##name: result.number = MATH(name)(x.number, y.number); break
#define INTEGER(name) case op_##name: integer = MATH(name)(x.number); break
#define SCALED(name, type) case op_##name: result.number = MATH(name)(x.number, (type)test->parameter); break
    UNARY(fabs);
    BINARY(copysign);
    UNARY(ceil);
    UNARY(floor);
    UNARY(trunc);
    UNARY(round);
    UNARY(nearbyint);
    UNARY(rint);
    INTEGER(lrint);
    INTEGER(llrint);
    INTEGER(lround);
    INTEGER(llround);
    case op_frexp: result.number = MATH(frexp)(x.number, &out); integer = out; break;
    SCALED(scalbn, int);
    SCALED(scalbln, long);
    SCALED(ldexp, int);
    case op_modf: result.number = MATH(modf)(x.number, &auxiliary.number); break;
    BINARY(nextafter);
    case op_nexttoward: result.number = MATH(nexttoward)(x.number, toward.number); break;
    INTEGER(ilogb);
    UNARY(logb);
    UNARY(sqrt);
    BINARY(fmin);
    BINARY(fmax);
    BINARY(fmod);
    BINARY(remainder);
    case op_remquo: result.number = MATH(remquo)(x.number, y.number, &out); integer = out; break;
    case op_nan: result.number = MATH(nan)(tags[test->parameter]); break;
    case op_fma: result.number = MATH(fma)(x.number, y.number, z.number); break;
    BINARY(fdim);
    UNARY(cbrt);
    BINARY(hypot);
    case op_classify: integer = class_bits(x.number); break;
    case op_compare: integer = compare_bits(x.number, y.number); break;
    case operation_count: break;
#undef UNARY
#undef BINARY
#undef INTEGER
#undef SCALED
    }

    struct machine_fenv current = observe();
    int error = *cell;
    install(original.control, original.mxcsr);
    if (!(test->policy == QUIET_NAN ? quiet_nan(result.encoded) :
                                     same_bits(result.encoded, test->wanted)))
        return 20;
    if (integer != test->integer || !same_bits(auxiliary.encoded, test->secondary))
        return 21;
    if (bits_only)
        return 0;
    if (error != (test->error ? test->error : TEST_ERRNO))
        return 22;
    if (((current.status | current.mxcsr) & FE_ALL_EXCEPT) != ((unsigned)test->flags | seed))
        return 23;
    if (current.control != control || (current.mxcsr & ~0x3fu) != (mxcsr & ~0x3fu))
        return 24;
    return 0;
}

static int next_packet(struct packet *test)
{
    unsigned char *destination = (unsigned char *)test;
    size_t count = 0;
    while (count < sizeof *test) {
        ssize_t got = read(STDIN_FILENO, destination + count, sizeof *test - count);
        if (got < 0 && errno == EINTR)
            continue;
        if (got <= 0)
            return got == 0 && !count ? 0 : -1;
        count += (size_t)got;
    }
    return 1;
}

int main(int argc, char **argv)
{
    int bits_only = argc == 2 && argv[1][0] == 'b' && argv[1][1] == '\0';
    if (argc != 1 && !bits_only)
        return 2;
    struct packet test;
    for (unsigned long record = 0;; ++record) {
        int present = next_packet(&test);
        if (present <= 0)
            return present < 0 ? 3 : 0;
        int status = check(&test, bits_only);
        if (status) {
            char message[88];
            int length = snprintf(message, sizeof message, "record %lu operation %u status %d\n",
                                  record, (unsigned)test.operation, status);
            if (length > 0 && (size_t)length < sizeof message)
                (void)write(STDERR_FILENO, message, (size_t)length);
            return status;
        }
    }
}
