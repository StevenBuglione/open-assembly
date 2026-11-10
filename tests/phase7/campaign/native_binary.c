/* Test-only MPFR binary32 producer for a fixed second-operand axis. */
#include <errno.h>
#include <float.h>
#include <mpfr.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

_Static_assert(FLT_MANT_DIG == 24 && sizeof(float) == 4, "binary32");

enum { INVALID = 1, DIVBYZERO = 4, OVERFLOW = 8, UNDERFLOW = 16, INEXACT = 32, TEST_ERRNO = 947 };
enum { BATCH = 512 };
#define OP(name) OP_##name,
#define OP2(name) OP(name)
enum operation {
#include "../transcendental/operations.def"
};
#undef OP2
#undef OP

struct request {
    uint64_t low;
    uint16_t high, mode;
    uint32_t operation;
    uint64_t other_low;
    uint16_t other_high, seed;
    uint32_t reserved;
};
struct response {
    uint64_t low;
    uint16_t high, flags;
    int32_t error;
};
_Static_assert(sizeof(struct request) == 32 && sizeof(struct response) == 16, "packet protocol");

union binary32 {
    uint32_t bits;
    float value;
};

static const uint32_t sign_bit = UINT32_C(0x80000000);
static const uint32_t infinity = UINT32_C(0x7f800000);
static const uint32_t one = UINT32_C(0x3f800000);
static const uint32_t quiet_bit = UINT32_C(0x00400000);
static const uint64_t domain = UINT64_C(1) << 32;

enum parity { NON_INTEGER, EVEN, ODD };

static enum parity integer_parity(uint32_t magnitude)
{
    unsigned exponent = magnitude >> 23;
    if (exponent < 127)
        return NON_INTEGER;
    if (exponent > 150)
        return EVEN;
    unsigned shift = 150 - exponent;
    if (magnitude & ((UINT32_C(1) << shift) - 1))
        return NON_INTEGER;
    return (magnitude >> shift) & 1 ? ODD : EVEN;
}

static bool expected(enum operation operation, uint32_t first, uint32_t second,
                     mpfr_t left, mpfr_t right, mpfr_t output, mpfr_rnd_t rounding,
                     struct response *result)
{
    uint32_t x = first & ~sign_bit, y = second & ~sign_bit;
    bool nan_x = x > infinity, nan_y = y > infinity;
    bool signal_x = nan_x && !(x & quiet_bit), signal_y = nan_y && !(y & quiet_bit);
    *result = (struct response){.error = TEST_ERRNO};
    if (signal_x || signal_y) {
        result->low = (signal_x ? first : second) | quiet_bit;
        result->flags = INVALID;
        return true;
    }
    if (operation == OP_pow && (!y || first == one)) {
        result->low = one;
        return true;
    }
    if (nan_x || nan_y) {
        result->low = nan_x ? first : second;
        return true;
    }
    if (operation == OP_pow) {
        if (y == infinity) {
            if (x == one)
                result->low = one;
            else if ((x > one) != (second != y))
                result->low = infinity;
            return true;
        }
        enum parity parity = integer_parity(y);
        uint32_t sign = parity == ODD ? first & sign_bit : 0;
        if (!x) {
            result->low = sign;
            if (second != y) {
                result->low |= infinity;
                result->flags = DIVBYZERO;
                result->error = ERANGE;
            }
            return true;
        }
        if (x == infinity) {
            result->low = sign | (second == y ? infinity : 0);
            return true;
        }
        if (first != x && parity == NON_INTEGER) {
            result->low = infinity | quiet_bit;
            result->flags = INVALID;
            result->error = EDOM;
            return true;
        }
    }

    union binary32 value = {.bits = first};
    mpfr_set_flt(left, value.value, MPFR_RNDN);
    mpfr_clear_flags();
    int ternary = operation == OP_pow ? mpfr_pow(output, left, right, rounding) :
                                       mpfr_atan2(output, left, right, rounding);
    mpfr_subnormalize(output, ternary, rounding);
    bool overflowed = mpfr_overflow_p(), inexact = mpfr_inexflag_p();
    if (mpfr_nan_p(output) || (mpfr_inf_p(output) && !overflowed))
        return false;
    value.value = mpfr_get_flt(output, MPFR_RNDN);
    result->low = value.bits;
    if (overflowed) {
        result->flags = OVERFLOW | INEXACT;
        result->error = ERANGE;
    } else if (inexact && (value.bits & ~sign_bit) < UINT32_C(0x00800000)) {
        result->flags = UNDERFLOW | INEXACT;
        result->error = ERANGE;
    } else if (inexact) {
        result->flags = INEXACT;
    }
    return true;
}

static bool index_argument(const char *text, uint64_t *value)
{
    char *end;
    errno = 0;
    unsigned long long parsed = strtoull(text, &end, 0);
    if (*text == '-' || errno || end == text || *end || parsed > domain)
        return false;
    *value = parsed;
    return true;
}

int main(int argc, char **argv)
{
    uint64_t first, count, mode, second;
    if (argc != 8 || !index_argument(argv[2], &first) || !index_argument(argv[3], &count) ||
        !index_argument(argv[4], &mode) || !index_argument(argv[5], &second) ||
        !count || count > domain - first || mode > 3 || second >= domain)
        return 2;
    enum operation operation;
    if (!strcmp(argv[1], "pow"))
        operation = OP_pow;
    else if (!strcmp(argv[1], "atan2"))
        operation = OP_atan2;
    else
        return 2;

    static const mpfr_rnd_t roundings[] = {MPFR_RNDN, MPFR_RNDD, MPFR_RNDU, MPFR_RNDZ};
    if (mpfr_set_emin(-148) || mpfr_set_emax(128))
        return 3;
    FILE *request_file = fopen(argv[6], "wb");
    FILE *response_file = fopen(argv[7], "wb");
    if (!request_file || !response_file)
        return 4;

    mpfr_t left, right, output;
    mpfr_inits2(24, left, right, output, (mpfr_ptr)0);
    union binary32 operand = {.bits = (uint32_t)second};
    if ((operand.bits & ~sign_bit) <= infinity)
        mpfr_set_flt(right, operand.value, MPFR_RNDN);
    struct request requests[BATCH];
    struct response responses[BATCH];
    for (uint64_t offset = 0; offset < count;) {
        size_t size = count - offset < BATCH ? (size_t)(count - offset) : BATCH;
        for (size_t i = 0; i < size; ++i) {
            uint32_t bits = (uint32_t)(first + offset + i);
            if (!expected(operation, bits, (uint32_t)second, left, right, output, roundings[mode], &responses[i]))
                return 5;
            uint16_t seed = responses[i].flags & DIVBYZERO ? UNDERFLOW : DIVBYZERO;
            responses[i].flags |= seed;
            requests[i] = (struct request){.low = bits, .mode = (uint16_t)(mode << 10),
                                           .operation = operation, .other_low = second, .seed = seed};
        }
        if (fwrite(requests, sizeof requests[0], size, request_file) != size ||
            fwrite(responses, sizeof responses[0], size, response_file) != size)
            return 6;
        offset += size;
    }
    mpfr_clears(output, right, left, (mpfr_ptr)0);
    int request_status = fclose(request_file);
    int response_status = fclose(response_file);
    return request_status || response_status ? 7 : 0;
}
