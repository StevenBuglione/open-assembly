/* Test-only MPFR binary32 oracle. The candidate runs in a separate process. */
#include <errno.h>
#include <float.h>
#include <mpfr.h>
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

typedef int (*unary_mpfr)(mpfr_ptr, mpfr_srcptr, mpfr_rnd_t);

static int log_abs_gamma(mpfr_ptr result, mpfr_srcptr input, mpfr_rnd_t rounding)
{
    int sign;
    return mpfr_lgamma(result, &sign, input, rounding);
}

static const struct {
    const char *name;
    enum operation operation;
    unary_mpfr evaluate;
} functions[] = {
    {"exp2", OP_exp2, mpfr_exp2}, {"log2", OP_log2, mpfr_log2},
    {"exp", OP_exp, mpfr_exp}, {"log", OP_log, mpfr_log},
    {"sin", OP_sin, mpfr_sin}, {"cos", OP_cos, mpfr_cos}, {"tan", OP_tan, mpfr_tan},
    {"log10", OP_log10, mpfr_log10}, {"expm1", OP_expm1, mpfr_expm1},
    {"log1p", OP_log1p, mpfr_log1p}, {"asin", OP_asin, mpfr_asin},
    {"acos", OP_acos, mpfr_acos}, {"atan", OP_atan, mpfr_atan},
    {"sinh", OP_sinh, mpfr_sinh}, {"cosh", OP_cosh, mpfr_cosh}, {"tanh", OP_tanh, mpfr_tanh},
    {"asinh", OP_asinh, mpfr_asinh}, {"acosh", OP_acosh, mpfr_acosh}, {"atanh", OP_atanh, mpfr_atanh},
    {"erf", OP_erf, mpfr_erf}, {"erfc", OP_erfc, mpfr_erfc},
    {"tgamma", OP_tgamma, mpfr_gamma}, {"lgamma", OP_lgamma, log_abs_gamma},
};

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
static const uint32_t two = UINT32_C(0x40000000);
static const uint32_t quiet = UINT32_C(0x00400000);

static uint16_t initial_flag(uint16_t required)
{
    return required & DIVBYZERO ? UNDERFLOW : DIVBYZERO;
}

static struct response answer(uint32_t bits, uint16_t flags, int error)
{
    return (struct response){bits, 0, (uint16_t)(flags | initial_flag(flags)), error};
}

static struct response exact(uint32_t bits)
{
    return answer(bits, 0, TEST_ERRNO);
}

static struct response domain(void)
{
    return answer(infinity | quiet, INVALID, EDOM);
}

static struct response pole(uint32_t sign)
{
    return answer(infinity | sign, DIVBYZERO, ERANGE);
}

static int ordinary_logarithm(enum operation operation)
{
    return operation == OP_log || operation == OP_log2 || operation == OP_log10;
}

static int integer_encoding(uint32_t magnitude)
{
    unsigned exponent = magnitude >> 23;
    return !magnitude || exponent >= 150 ||
           (exponent >= 127 && !(magnitude & ((UINT32_C(1) << (150 - exponent)) - 1)));
}

static struct response expected(enum operation operation, unary_mpfr evaluate, uint32_t bits,
                                mpfr_t input, mpfr_t output, mpfr_rnd_t rounding)
{
    uint32_t magnitude = bits & ~sign_bit, sign = bits & sign_bit;
    if (magnitude > infinity)
        return answer(bits | quiet, bits & quiet ? 0 : INVALID, TEST_ERRNO);
    if (ordinary_logarithm(operation)) {
        if (!magnitude)
            return pole(sign_bit);
        if (sign)
            return domain();
        if (magnitude == one)
            return exact(0);
    }
    if (operation == OP_log1p && sign && magnitude >= one)
        return magnitude == one ? pole(sign_bit) : domain();
    if ((operation == OP_asin || operation == OP_acos) && magnitude > one)
        return domain();
    if (operation == OP_acosh && (sign || magnitude < one))
        return domain();
    if ((operation == OP_acosh || operation == OP_acos) && bits == one)
        return exact(0);
    if (operation == OP_atanh && magnitude >= one)
        return magnitude == one ? pole(sign) : domain();

    if (operation == OP_tgamma || operation == OP_lgamma) {
        if (!magnitude)
            return pole(operation == OP_tgamma ? sign : 0);
        if (magnitude == infinity)
            return operation == OP_tgamma && sign ? domain() : exact(infinity);
        if (sign && integer_encoding(magnitude))
            return operation == OP_tgamma ? domain() : pole(0);
        if (operation == OP_lgamma && (bits == one || bits == two))
            return exact(0);
    }

    if (!magnitude && operation != OP_acos) {
        switch (operation) {
        case OP_exp: case OP_exp2: case OP_cos: case OP_cosh: case OP_erfc:
            return exact(one);
        default:
            return exact(bits);
        }
    }
    if (magnitude == infinity) {
        switch (operation) {
        case OP_exp: case OP_exp2:
            return exact(sign ? 0 : infinity);
        case OP_expm1:
            return exact(sign ? one | sign : infinity);
        case OP_log: case OP_log2: case OP_log10: case OP_log1p: case OP_acosh:
            return exact(infinity);
        case OP_sinh: case OP_asinh:
            return exact(bits);
        case OP_cosh:
            return exact(infinity);
        case OP_erf: case OP_tanh:
            return exact(one | sign);
        case OP_erfc:
            return exact(sign ? two : 0);
        case OP_atan:
            break;  /* MPFR rounds the nonfinite limit +/- pi/2. */
        default:
            return domain();
        }
    }

    union binary32 value = {.bits = bits};
    mpfr_set_flt(input, value.value, MPFR_RNDN);
    mpfr_clear_flags();
    int ternary = evaluate(output, input, rounding);
    ternary = mpfr_subnormalize(output, ternary, rounding);
    int overflowed = mpfr_overflow_p();
    value.value = mpfr_get_flt(output, MPFR_RNDN);
    if (overflowed)
        return answer(value.bits, OVERFLOW | INEXACT, ERANGE);
    if (ternary && (value.bits & ~sign_bit) < UINT32_C(0x00800000))
        return answer(value.bits, UNDERFLOW | INEXACT, ERANGE);
    return answer(value.bits, ternary ? INEXACT : 0, TEST_ERRNO);
}

static int index_argument(const char *text, uint64_t *value)
{
    char *end;
    errno = 0;
    unsigned long long parsed = strtoull(text, &end, 0);
    if (errno || end == text || *end || parsed > (UINT64_C(1) << 32))
        return 0;
    *value = parsed;
    return 1;
}

int main(int argc, char **argv)
{
    uint64_t first, count, mode;
    if (argc != 7 || !index_argument(argv[2], &first) || !index_argument(argv[3], &count) ||
        !index_argument(argv[4], &mode) || !count || count > (UINT64_C(1) << 32) - first || mode > 3)
        return 2;
    size_t selected = 0;
    const size_t operation_count = sizeof functions / sizeof *functions;
    while (selected < operation_count && strcmp(argv[1], functions[selected].name))
        ++selected;
    if (selected == operation_count)
        return 2;
    enum operation operation = functions[selected].operation;
    static const mpfr_rnd_t roundings[] = {MPFR_RNDN, MPFR_RNDD, MPFR_RNDU, MPFR_RNDZ};
    if (mpfr_set_emin(-148) || mpfr_set_emax(128))
        return 3;
    FILE *request_file = fopen(argv[5], "wb");
    FILE *response_file = fopen(argv[6], "wb");
    if (!request_file || !response_file)
        return 4;

    mpfr_t input, output;
    mpfr_init2(input, 24);
    mpfr_init2(output, 24);
    struct request requests[BATCH];
    struct response responses[BATCH];
    for (uint64_t offset = 0; offset < count;) {
        size_t size = count - offset < BATCH ? (size_t)(count - offset) : BATCH;
        for (size_t i = 0; i < size; ++i) {
            uint32_t bits = (uint32_t)(first + offset + i);
            responses[i] = expected(operation, functions[selected].evaluate, bits, input, output,
                                    roundings[mode]);
            unsigned seed = responses[i].error == ERANGE &&
                            responses[i].flags == (DIVBYZERO | UNDERFLOW) ? UNDERFLOW : DIVBYZERO;
            requests[i] = (struct request){.low = bits, .mode = (uint16_t)(mode << 10),
                                           .operation = operation, .seed = (uint16_t)seed};
        }
        if (fwrite(requests, sizeof requests[0], size, request_file) != size ||
            fwrite(responses, sizeof responses[0], size, response_file) != size)
            return 5;
        offset += size;
    }
    mpfr_clear(output);
    mpfr_clear(input);
    int request_status = fclose(request_file);
    int response_status = fclose(response_file);
    return request_status || response_status ? 6 : 0;
}
