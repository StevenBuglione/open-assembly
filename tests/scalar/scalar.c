#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <stdlib.h>

#include "../phase2/test.h"

#if TEST_FUNCTION_ID == 48 || TEST_FUNCTION_ID == 51
typedef int scalar;
#define MINIMUM INT_MIN
#define MAXIMUM INT_MAX
#elif TEST_FUNCTION_ID == 49 || TEST_FUNCTION_ID == 52
typedef long scalar;
#define MINIMUM LONG_MIN
#define MAXIMUM LONG_MAX
#elif TEST_FUNCTION_ID == 50 || TEST_FUNCTION_ID == 53
typedef long long scalar;
#define MINIMUM LLONG_MIN
#define MAXIMUM LLONG_MAX
#elif TEST_FUNCTION_ID == 54 || TEST_FUNCTION_ID == 55
typedef intmax_t scalar;
#define MINIMUM INTMAX_MIN
#define MAXIMUM INTMAX_MAX
#else
#error unsupported C17 scalar function
#endif

#if TEST_FUNCTION_ID == 51
typedef div_t pair;
#elif TEST_FUNCTION_ID == 52
typedef ldiv_t pair;
#elif TEST_FUNCTION_ID == 53
typedef lldiv_t pair;
#elif TEST_FUNCTION_ID == 55
typedef imaxdiv_t pair;
#endif

#if (TEST_FUNCTION_ID >= 51 && TEST_FUNCTION_ID <= 53) || TEST_FUNCTION_ID == 55
#define DIVISION 1
extern pair CANDIDATE(scalar numerator, scalar denominator);
#else
extern scalar CANDIDATE(scalar value);
#endif

#ifndef TEST_LIBFUZZER
extern int phase2_abi_result(uintptr_t function, const uint64_t arguments[6],
                            uint64_t return_bits[2]);
static int check_return_registers(void);
#endif

static const scalar boundaries[] = {
    -37, 37, 0, 1, -1, 2, -2, 32767, -32768,
    MAXIMUM, -MAXIMUM, MAXIMUM - 1, MINIMUM + 2,
#if TEST_FUNCTION_ID != 48 && TEST_FUNCTION_ID != 51
    INT32_MAX, INT32_MIN, INT64_C(0x100000001), -INT64_C(0x100000001),
    INT64_C(0x4000000080000001), -INT64_C(0x4000000080000001),
#endif
};

#define ARRAY_SIZE(array) (sizeof(array) / sizeof(*(array)))

static scalar random_value(uint32_t *state)
{
    uint64_t high = phase2_next(state), low = phase2_next(state);
    uint64_t bits = (high << 32) | low;
    uint64_t magnitude = bits & (uint64_t)MAXIMUM;
    return bits >> 63 ? -(scalar)magnitude : (scalar)magnitude;
}

#ifdef DIVISION
static const scalar denominators[] = {
    5, -5, 1, -1, 2, -2, 7, -7, MAXIMUM, MINIMUM,
#if TEST_FUNCTION_ID != 51
    INT64_C(0x100000001), -INT64_C(0x100000001),
#endif
};

static uint64_t magnitude(scalar value)
{
    return value < 0 ? (uint64_t)(-(value + 1)) + 1 : (uint64_t)value;
}

static scalar with_sign(uint64_t magnitude, int negative)
{
    if (!negative || magnitude == 0)
        return (scalar)magnitude;
    return -(scalar)(magnitude - 1) - 1;
}

/* Binary restoring division on magnitudes implements truncation toward zero
   without using the host division or remainder operation as the oracle. */
static pair reference_division(scalar numerator, scalar denominator)
{
    uint64_t remaining = magnitude(numerator), divisor = magnitude(denominator);
    uint64_t quotient = 0;
    for (unsigned bit = sizeof(scalar) * CHAR_BIT; bit-- != 0;) {
        if ((remaining >> bit) >= divisor) {
            remaining -= divisor << bit;
            quotient |= UINT64_C(1) << bit;
        }
    }
    return (pair){
        .quot = with_sign(quotient, (numerator < 0) != (denominator < 0)),
        .rem = with_sign(remaining, numerator < 0),
    };
}

#define DIRECTED_CASES ((ARRAY_SIZE(boundaries) + 1) * ARRAY_SIZE(denominators))

static int sample(size_t index, uint32_t *state, int compare_host)
{
#ifndef TEST_LIBFUZZER
    if (index == 0 && !compare_host) {
        int status = check_return_registers();
        if (status)
            return status;
    }
#endif
    scalar numerator, denominator;
    if (index < DIRECTED_CASES) {
        size_t row = index / ARRAY_SIZE(denominators);
        numerator = row == ARRAY_SIZE(boundaries) ? MINIMUM : boundaries[row];
        denominator = denominators[index % ARRAY_SIZE(denominators)];
    } else {
        numerator = index % 19 == 0 ? MINIMUM : random_value(state);
        switch (index % 4) {
        case 0: denominator = random_value(state); break;
        case 1: denominator = (scalar)(int16_t)phase2_next(state); break;
        case 2: denominator = denominators[phase2_next(state) % ARRAY_SIZE(denominators)]; break;
        default: denominator = boundaries[phase2_next(state) % ARRAY_SIZE(boundaries)]; break;
        }
    }
    if (!denominator || (numerator == MINIMUM && denominator == -1))
        denominator = 1;

    pair expected = reference_division(numerator, denominator);
    errno = EDOM;
    pair actual = CANDIDATE(numerator, denominator);
    if (actual.quot != expected.quot || actual.rem != expected.rem || errno != EDOM)
        return phase2_fail("%jd / %jd yielded (%jd,%jd) errno %d, expected (%jd,%jd)",
                           (intmax_t)numerator, (intmax_t)denominator,
                           (intmax_t)actual.quot, (intmax_t)actual.rem, errno,
                           (intmax_t)expected.quot, (intmax_t)expected.rem);
    if (compare_host) {
        pair hosted = TEST_NAME(numerator, denominator);
        if (actual.quot != hosted.quot || actual.rem != hosted.rem)
            return phase2_fail("host disagreed for %jd / %jd", (intmax_t)numerator,
                               (intmax_t)denominator);
    }
    return 0;
}
#else
#define DIRECTED_CASES ARRAY_SIZE(boundaries)

static int sample(size_t index, uint32_t *state, int compare_host)
{
#ifndef TEST_LIBFUZZER
    if (index == 0 && !compare_host) {
        int status = check_return_registers();
        if (status)
            return status;
    }
#endif
    scalar value = index < DIRECTED_CASES ? boundaries[index] : random_value(state);
    scalar expected = value < 0 ? -value : value;
    errno = EDOM;
    scalar actual = CANDIDATE(value);
    if (actual != expected || errno != EDOM)
        return phase2_fail("magnitude of %jd yielded %jd errno %d, expected %jd",
                           (intmax_t)value, (intmax_t)actual, errno, (intmax_t)expected);
    if (compare_host && actual != TEST_NAME(value))
        return phase2_fail("host disagreed for magnitude of %jd", (intmax_t)value);
    return 0;
}
#endif

static const uint64_t abi_arguments[6] = {
#if TEST_FUNCTION_ID == 48 || TEST_FUNCTION_ID == 51
    UINT64_C(0x19283746ffffffdb), UINT64_C(0xe49128a300000005),
#else
    (uint64_t)-INT64_C(0x100000001), 5,
#endif
};

static int abi(void)
{
    return phase2_abi(ADDRESS(CANDIDATE), abi_arguments);
}

#ifndef TEST_LIBFUZZER
static int check_return_registers(void)
{
    uint64_t result[2] = {UINT64_MAX, UINT64_MAX};
    errno = EDOM;
    int mask = phase2_abi_result(ADDRESS(CANDIDATE), abi_arguments, result);
    if (mask || errno != EDOM)
        return phase2_fail("callee state mask %#x, errno %d", (unsigned)mask, errno);
#if TEST_FUNCTION_ID == 48
    if ((uint32_t)result[0] != 37)
        return phase2_fail("wrong signed int result in EAX");
#elif TEST_FUNCTION_ID == 51
    if (result[0] != UINT64_C(0xfffffffefffffff9))
        return phase2_fail("wrong packed int quotient/remainder in RAX");
#elif defined(DIVISION)
    if (result[0] != (uint64_t)-INT64_C(858993459) || result[1] != (uint64_t)-INT64_C(2))
        return phase2_fail("wrong 64-bit quotient/remainder in RAX/RDX");
#else
    if (result[0] != UINT64_C(0x100000001))
        return phase2_fail("wrong 64-bit magnitude in RAX");
#endif
    return 0;
}

#endif

const struct phase2_fixture fixture = {
    .name = STR(TEST_NAME),
    .unit_oracle = "reference:c17-integer-arithmetic",
    .directed_cases = DIRECTED_CASES,
    .abi = abi,
    .sample = sample,
};
