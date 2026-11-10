#include <errno.h>
#include <fenv.h>
#include <float.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

#include "stdio_check.h"

static int matched(const char *actual, int result, const char *expected)
{
    return result >= 0 && (size_t)result == length(expected) && equal(actual, expected);
}

static int call_vsnprintf(char *out, size_t size, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = vsnprintf(out, size, format, arguments);
    va_end(arguments);
    return result;
}

static int call_vprintf(const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = vprintf(format, arguments);
    va_end(arguments);
    return result;
}

static int decimal_formats(void)
{
    char out[160];
    int result = snprintf(out, sizeof out, "%.3g|%#.3g|%.3g|%.3G|%.4g|%.1e",
                          1234.0, 12.0, 0.000125, 0.0000125, 9.999755859375, 9.96875);
    REQUIRE(matched(out, result, "1.23e+03|12.0|0.000125|1.25E-05|10|1.0e+01"), 20);
    result = snprintf(out, sizeof out, "%.17g|%.17e|%+.2f", DBL_MAX, DBL_TRUE_MIN, -0.0);
    REQUIRE(matched(out, result, "1.7976931348623157e+308|4.94065645841246544e-324|-0.00"), 21);
    result = snprintf(out, sizeof out, "%+010.2f|%-8.2f|%#.0f", 1.25, -2.5, 3.0);
    REQUIRE(matched(out, result, "+000001.25|-2.50   |3."), 22);
    char small[7] = "!!!!!!";
    REQUIRE(snprintf(small + 1, 4, "%.2f", 125.0) == 6
            && equal(small + 1, "125") && small[0] == '!' && small[5] == '!', 23);
    return 0;
}

static int directed_formats(void)
{
    static const struct {
        unsigned mode;
        const char *expected;
    } cases[] = {
        {FE_TONEAREST, "2|-2|0.12|-0.12|1.0e+01"},
        {FE_DOWNWARD, "2|-3|0.12|-0.13|9.9e+00"},
        {FE_UPWARD, "3|-2|0.13|-0.12|1.0e+01"},
        {FE_TOWARDZERO, "2|-2|0.12|-0.12|9.9e+00"},
    };
    char out[48];
    for (size_t i = 0; i < sizeof cases / sizeof cases[0]; ++i) {
        rounding(cases[i].mode);
#ifndef OA_PHASE5_HOST
        struct machine_fenv before = observe();
#endif
        int result = snprintf(out, sizeof out, "%.0f|%.0f|%.2f|%.2f|%.1e",
                              2.5, -2.5, 0.125, -0.125, 9.96875);
        REQUIRE(matched(out, result, cases[i].expected), 24);
#ifndef OA_PHASE5_HOST
        struct machine_fenv after = observe();
        REQUIRE(after.control == before.control && after.mxcsr == before.mxcsr
                && ((after.status ^ before.status) & FE_ALL_EXCEPT) == 0, 31);
#endif
    }
    return 0;
}

static int variadic_formats(void)
{
    char out[200];
    int result = call_vsnprintf(out, sizeof out,
                               "%d|%.1f|%.1Lf|%d|%.1f|%.1f|%.1f|%.1f|%.1f|%.1f|%.1f|%.1f|%.20Lf|%d|%d",
                               7, 1.5, 2.5L, 8, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5, 10.5,
                               0x1.0000000000000002p0L, 9, 10);
    REQUIRE(matched(out, result,
                    "7|1.5|2.5|8|3.5|4.5|5.5|6.5|7.5|8.5|9.5|10.5|1.00000000000000000011|9|10"), 25);
    return 0;
}

static int hexadecimal(void)
{
    char out[96], *end;
    int result = snprintf(out, sizeof out, "%.3a", 1.5);
    REQUIRE(result > 0 && (size_t)result == length(out) && out[0] == '0' && out[1] == 'x'
            && strtod(out, &end) == 1.5 && !*end, 26);
    result = snprintf(out, sizeof out, "%.0A", 1.5);
    REQUIRE(result > 0 && (size_t)result == length(out) && out[0] == '0' && out[1] == 'X'
            && strtod(out, &end) == 2.0 && !*end, 27);
    result = snprintf(out, sizeof out, "%La", 0x1.0000000000000002p0L);
    REQUIRE(result > 0 && (size_t)result == length(out)
            && extended_next(strtold(out, &end)) && !*end, 28);
    return 0;
}

static int special_formats(void)
{
    union { double value; uint64_t bits; } inf = {.bits = UINT64_C(0x7ff0000000000000)},
        nan = {.bits = UINT64_C(0x7ff8000000000000)};
    char out[96];
    int result = snprintf(out, sizeof out, "%+f|%F|%e|%.1g", inf.value, -inf.value, nan.value, -0.0);
    REQUIRE(matched(out, result, "+inf|-INF|nan|-0"), 29);
    return 0;
}

static int conversion_range(void)
{
    static int (*volatile format_probe)(char *, size_t, const char *, ...) = snprintf;
    errno = 0;
    REQUIRE(format_probe(NULL, 0, "%.2147483647f", 0.0) < 0 && errno == EOVERFLOW, 30);
    return 0;
}

static int dispatch(const char *mode)
{
    if (equal(mode, "decimal"))
        return decimal_formats();
    if (equal(mode, "rounding"))
        return directed_formats();
    if (equal(mode, "variadic"))
        return variadic_formats();
    if (equal(mode, "hex"))
        return hexadecimal();
    if (equal(mode, "special"))
        return special_formats();
    if (equal(mode, "overflow"))
        return conversion_range();
    if (equal(mode, "stdout")) {
        REQUIRE(printf("%+.2f|", 1.25) == 6, 60);
        REQUIRE(call_vprintf("%.2Lf", -2.5L) == 5, 61);
        return 0;
    }
    return 10;
}

int main(int argc, char **argv)
{
    REQUIRE(argc == 2, 9);
    struct machine_fenv initial = observe();
    rounding(FE_TONEAREST);
    int status = dispatch(argv[1]);
    install(initial.control, initial.mxcsr);
    return status;
}
