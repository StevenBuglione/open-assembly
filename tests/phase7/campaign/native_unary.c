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

static const struct {
    const char *name;
    enum operation operation;
    unary_mpfr evaluate;
} functions[] = {
    {"exp2", OP_exp2, mpfr_exp2}, {"log2", OP_log2, mpfr_log2},
    {"exp", OP_exp, mpfr_exp}, {"log", OP_log, mpfr_log},
    {"sin", OP_sin, mpfr_sin}, {"cos", OP_cos, mpfr_cos}, {"tan", OP_tan, mpfr_tan},
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

static struct response expected(enum operation operation, unary_mpfr evaluate, uint32_t bits,
                                mpfr_t input, mpfr_t output, mpfr_rnd_t rounding)
{
    const uint32_t magnitude = bits & UINT32_C(0x7fffffff);
    const uint32_t infinity = UINT32_C(0x7f800000);
    const uint32_t quiet = UINT32_C(0x00400000);
    const uint32_t one = UINT32_C(0x3f800000);
    const int logarithm = operation == OP_log || operation == OP_log2;
    const int trigonometric = operation == OP_sin || operation == OP_cos || operation == OP_tan;
    struct response result = {0, 0, DIVBYZERO, TEST_ERRNO};
    if (magnitude > infinity) {
        result.low = bits | quiet;
        if (!(bits & quiet))
            result.flags |= INVALID;
    } else if (logarithm && !magnitude) {
        result.low = UINT32_C(0xff800000);
        result.flags = DIVBYZERO | UNDERFLOW;
        result.error = ERANGE;
    } else if ((logarithm && bits >> 31) || (trigonometric && magnitude == infinity)) {
        result.low = UINT32_C(0x7fc00000);
        result.flags |= INVALID;
        result.error = EDOM;
    } else if (magnitude == infinity) {
        result.low = bits == infinity ? infinity : 0;
    } else if (!magnitude) {
        result.low = operation == OP_sin || operation == OP_tan ? bits : one;
    } else if (logarithm && bits == one) {
        result.low = 0;
    } else {
        union binary32 value = {.bits = bits};
        mpfr_set_flt(input, value.value, MPFR_RNDN);
        mpfr_clear_flags();
        int ternary = evaluate(output, input, rounding);
        ternary = mpfr_subnormalize(output, ternary, rounding);
        int overflowed = mpfr_overflow_p();
        value.value = mpfr_get_flt(output, MPFR_RNDN);
        result.low = value.bits;
        if (overflowed) {
            result.flags |= OVERFLOW | INEXACT;
            result.error = ERANGE;
        } else if (ternary) {
            result.flags |= INEXACT;
            if ((value.bits & UINT32_C(0x7fffffff)) < UINT32_C(0x00800000)) {
                result.flags |= UNDERFLOW;
                result.error = ERANGE;
            }
        }
    }
    return result;
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
            unsigned seed = responses[i].flags == (DIVBYZERO | UNDERFLOW) ? UNDERFLOW : DIVBYZERO;
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
