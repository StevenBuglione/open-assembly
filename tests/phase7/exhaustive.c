#include <errno.h>
#include <fenv.h>
#include <limits.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

#include "../phase5/fp_machine.h"

enum operation {
    CLASS, SIGN, ABS, COPY, CEIL, FLOOR, TRUNC, ROUND, NEARBY, RINT, FREXP, ILOGB, LOGB, MODF
};

struct named_operation {
    const char *name;
    enum operation operation;
};

static const struct named_operation operations[] = {
    {"class", CLASS}, {"sign", SIGN}, {"fabsf", ABS}, {"copysignf", COPY},
    {"ceilf", CEIL}, {"floorf", FLOOR}, {"truncf", TRUNC}, {"roundf", ROUND},
    {"nearbyintf", NEARBY}, {"rintf", RINT}, {"frexpf", FREXP},
    {"ilogbf", ILOGB}, {"logbf", LOGB}, {"modff", MODF}
};
static const uint32_t sign_mask = UINT32_C(0x80000000);
static const uint32_t fraction_mask = UINT32_C(0x007fffff);
static const uint32_t infinity = UINT32_C(0x7f800000);
static const uint32_t quiet_bit = UINT32_C(0x00400000);

enum { TEST_ERRNO = 947, SEED_FLAGS = FE_DIVBYZERO };

union number {
    float fp;
    uint32_t bits;
};

struct outcome {
    uint32_t result, secondary;
    int integer, flags, error;
};

static unsigned leading_bit(uint32_t value)
{
    return (unsigned)(31 - __builtin_clz(value));
}

static uint32_t encode_integral(int value)
{
    if (!value)
        return 0;
    uint32_t magnitude = (uint32_t)(value < 0 ? -value : value);
    unsigned leading = leading_bit(magnitude);
    return (value < 0 ? sign_mask : 0) | ((leading + 127) << 23) |
           ((magnitude << (23 - leading)) & fraction_mask);
}

static int exponent_of(uint32_t magnitude)
{
    unsigned exponent_field = magnitude >> 23;
    return exponent_field ? (int)exponent_field - 127 : (int)leading_bit(magnitude) - 149;
}

static uint32_t integral_bits(uint32_t bits, int mode, int ties_away)
{
    uint32_t magnitude = bits & ~sign_mask;
    uint32_t sign = bits & sign_mask;
    unsigned exponent = magnitude >> 23;
    if (exponent >= 150 || !magnitude)
        return bits;
    int outward = (sign && mode == FE_DOWNWARD) || (!sign && mode == FE_UPWARD);
    if (exponent < 127) {
        uint32_t half = UINT32_C(0x3f000000);
        int nearest = mode == FE_TONEAREST && (magnitude > half ||
                                               (ties_away && magnitude == half));
        return sign | (outward || nearest ? UINT32_C(0x3f800000) : 0);
    }
    uint32_t step = UINT32_C(1) << (150 - exponent);
    uint32_t remainder = magnitude & (step - 1);
    uint32_t integral = magnitude - remainder;
    if (remainder) {
        uint32_t half = step >> 1;
        int nearest = mode == FE_TONEAREST &&
                      (remainder > half || (remainder == half && (ties_away || (integral & step))));
        if (outward || nearest)
            integral += step;
    }
    return sign | integral;
}

static struct outcome reference(enum operation op, uint32_t bits, int mode)
{
    uint32_t magnitude = bits & ~sign_mask;
    uint32_t sign = bits & sign_mask;
    struct outcome want = {0, 0, 0, 0, TEST_ERRNO};

    if (op == CLASS) {
        want.integer = magnitude > infinity ? FP_NAN : magnitude == infinity ? FP_INFINITE :
                       !magnitude ? FP_ZERO : magnitude >> 23 ? FP_NORMAL : FP_SUBNORMAL;
        return want;
    }
    if (op == SIGN) {
        want.integer = !!sign;
        return want;
    }
    if (op == ABS || op == COPY) {
        want.result = magnitude;
        want.secondary = op == COPY ? magnitude | sign_mask : 0;
        return want;
    }
    if (op == ILOGB) {
        if (!magnitude || magnitude >= infinity) {
            want.integer = magnitude == infinity ? INT_MAX : INT_MIN;
            want.flags = FE_INVALID;
            want.error = EDOM;
        } else {
            want.integer = exponent_of(magnitude);
        }
        return want;
    }
    if (magnitude > infinity) {
        want.result = bits | quiet_bit;
        if (op == MODF)
            want.secondary = want.result;
        if (!(bits & quiet_bit))
            want.flags = FE_INVALID;
        return want;
    }
    if (op == LOGB) {
        if (!magnitude) {
            want.result = sign_mask | infinity;
            want.flags = FE_DIVBYZERO;
            want.error = ERANGE;
        } else {
            want.result = magnitude == infinity ? infinity : encode_integral(exponent_of(magnitude));
        }
        return want;
    }
    if (op == FREXP) {
        want.result = bits;
        if (magnitude && magnitude != infinity) {
            int exponent = exponent_of(magnitude);
            unsigned shift = magnitude >> 23 ? 0 : (unsigned)(-126 - exponent);
            want.result = sign | (UINT32_C(126) << 23) | ((magnitude << shift) & fraction_mask);
            want.integer = exponent + 1;
        }
        return want;
    }
    if (op == MODF) {
        want.secondary = integral_bits(bits, FE_TOWARDZERO, 0);
        want.result = sign;
        unsigned exponent = magnitude >> 23;
        if (exponent < 127) {
            want.result = bits;
        } else if (exponent < 150) {
            uint32_t remainder = magnitude & ((UINT32_C(1) << (150 - exponent)) - 1);
            if (remainder) {
                unsigned lead = leading_bit(remainder);
                want.result |= (exponent + lead - 23) << 23;
                want.result |= (remainder << (23 - lead)) & fraction_mask;
            }
        }
        return want;
    }
    if (op == CEIL)
        mode = FE_UPWARD;
    else if (op == FLOOR)
        mode = FE_DOWNWARD;
    else if (op == TRUNC)
        mode = FE_TOWARDZERO;
    else if (op == ROUND)
        mode = FE_TONEAREST;
    want.result = integral_bits(bits, mode, op == ROUND);
    if (op == RINT && want.result != bits)
        want.flags = FE_INEXACT;
    return want;
}

static struct outcome candidate(enum operation op, uint32_t bits)
{
    union number input = {.bits = bits}, result = {0}, secondary = {0};
    struct outcome got = {0};
    int out_integer = INT_MAX - 11;
    volatile int *cell = __errno_location();
    *cell = TEST_ERRNO;
    switch (op) {
    case CLASS:
        got.integer = fpclassify(input.fp);
        if (!!isfinite(input.fp) != (got.integer != FP_NAN && got.integer != FP_INFINITE) ||
            !!isinf(input.fp) != (got.integer == FP_INFINITE) ||
            !!isnan(input.fp) != (got.integer == FP_NAN) ||
            !!isnormal(input.fp) != (got.integer == FP_NORMAL))
            got.integer = -1;
        break;
    case SIGN: got.integer = !!signbit(input.fp); break;
    case ABS: result.fp = fabsf(input.fp); break;
    case COPY:
        result.fp = copysignf(input.fp, 0.0f);
        secondary.fp = copysignf(input.fp, -0.0f);
        break;
    case CEIL: result.fp = ceilf(input.fp); break;
    case FLOOR: result.fp = floorf(input.fp); break;
    case TRUNC: result.fp = truncf(input.fp); break;
    case ROUND: result.fp = roundf(input.fp); break;
    case NEARBY: result.fp = nearbyintf(input.fp); break;
    case RINT: result.fp = rintf(input.fp); break;
    case FREXP:
        result.fp = frexpf(input.fp, &out_integer);
        got.integer = out_integer;
        break;
    case ILOGB: got.integer = ilogbf(input.fp); break;
    case LOGB: result.fp = logbf(input.fp); break;
    case MODF: result.fp = modff(input.fp, &secondary.fp); break;
    }
    struct machine_fenv state = observe();
    got.result = result.bits;
    got.secondary = secondary.bits;
    got.flags = (int)((state.status | state.mxcsr) & FE_ALL_EXCEPT);
    got.error = *cell;
    return got;
}

static int equal(const char *left, const char *right)
{
    while (*left && *left == *right) {
        ++left;
        ++right;
    }
    return *left == *right;
}

static int parse_index(const char *text, uint64_t *result)
{
    int base = 10;
    if (text[0] == '0' && text[1] == 'x') {
        base = 16;
        text += 2;
    }
    if (!*text)
        return 0;
    uint64_t number = 0;
    while (*text) {
        char c = *text++;
        unsigned digit;
        if (c >= '0' && c <= '9')
            digit = (unsigned)(c - '0');
        else if (c >= 'a' && c <= 'f')
            digit = (unsigned)(c - 'a' + 10);
        else
            return 0;
        if (digit >= (unsigned)base || number > (UINT64_C(1) << 32))
            return 0;
        number = number * (unsigned)base + digit;
    }
    if (number > (UINT64_C(1) << 32))
        return 0;
    *result = number;
    return 1;
}

static int different(struct outcome got, struct outcome want)
{
    return got.result != want.result || got.secondary != want.secondary ||
           got.integer != want.integer || got.flags != want.flags || got.error != want.error;
}

static int report_failure(const char *name, uint32_t bits, int mode,
                          struct outcome got, struct outcome want)
{
    char buffer[256];
    int length = snprintf(buffer, sizeof buffer,
                          "%s %08x mode %x: got %08x,%08x,%d,%x,%d expected %08x,%08x,%d,%x,%d\n",
                          name, bits, (unsigned)mode, got.result, got.secondary, got.integer,
                          (unsigned)got.flags, got.error, want.result, want.secondary, want.integer,
                          (unsigned)want.flags, want.error);
    if (length <= 0 || (size_t)length >= sizeof buffer ||
        write(STDERR_FILENO, buffer, (size_t)length) != length)
        return 4;
    return 5;
}

int main(int argc, char **argv)
{
    const uint64_t bit_count = UINT64_C(1) << 32;
    static const int modes[] = {FE_TONEAREST, FE_DOWNWARD, FE_UPWARD, FE_TOWARDZERO};
    uint64_t mode_index, start, count;
    if (argc != 5 || !parse_index(argv[2], &mode_index) || mode_index >= 4 ||
        !parse_index(argv[3], &start) || !parse_index(argv[4], &count) ||
        !count || count > bit_count - start)
        return 2;

    const struct named_operation *selection = NULL;
    for (size_t i = 0; i < sizeof operations / sizeof operations[0]; ++i) {
        if (equal(argv[1], operations[i].name))
            selection = &operations[i];
    }
    if (!selection)
        return 3;

    int mode = modes[mode_index];
    struct machine_fenv original = observe();
    unsigned short control = (unsigned short)((original.control & ~0x0c00u) | (unsigned)mode);
    unsigned int mxcsr = (original.mxcsr & ~(0x6000u | 0x3fu)) |
                         ((unsigned int)mode << 3) | SEED_FLAGS;
    for (uint64_t index = start; index < start + count; ++index) {
        uint32_t bits = (uint32_t)index;
        struct outcome want = reference(selection->operation, bits, mode);
        want.flags |= SEED_FLAGS;
        install(control, mxcsr);
        struct outcome got = candidate(selection->operation, bits);
        struct machine_fenv current = observe();
        if (different(got, want)) {
            install(original.control, original.mxcsr);
            return report_failure(selection->name, bits, mode, got, want);
        }
        if (current.control != control || (current.mxcsr & ~0x3fu) != (mxcsr & ~0x3fu)) {
            install(original.control, original.mxcsr);
            return 6;
        }
    }
    install(original.control, original.mxcsr);
    return 0;
}
