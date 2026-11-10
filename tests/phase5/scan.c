#include <fenv.h>
#include <stdarg.h>
#include <stdio.h>

#include "stdio_check.h"

static int call_vsscanf(const char *text, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = vsscanf(text, format, arguments);
    va_end(arguments);
    return result;
}

static int call_vscanf(const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = vscanf(format, arguments);
    va_end(arguments);
    return result;
}

static int scan_values(void)
{
    static const char input[] = "1.000000059604644775390625 -0x1p-1074 0x1.0000000000000002p0 -0 INF NaN";
    float a = 0, zero = 1;
    double subnormal = 0, inf = 0, nan = 0;
    long double extended = 0;
    int consumed = -1;
    int result = call_vsscanf(input, "%f %la %Lf %f %lf %lf%n",
                              &a, &subnormal, &extended, &zero, &inf, &nan, &consumed);
    REQUIRE(result == 6 && consumed == sizeof input - 1, 40);
    REQUIRE(float_bits(a) == UINT32_C(0x3f800000)
            && double_bits(subnormal) == UINT64_C(0x8000000000000001)
            && extended_next(extended) && float_bits(zero) == UINT32_C(0x80000000)
            && double_bits(inf) == UINT64_C(0x7ff0000000000000), 41);
    REQUIRE((double_bits(nan) & UINT64_C(0x7fffffffffffffff)) > UINT64_C(0x7ff0000000000000), 42);
    return 0;
}

static int scan_rounding(void)
{
    static const char midpoint[] = "1.000000059604644775390625";
    static const char above[] = "1.0000000596046447753906250000000000000000001";
    static const char above_double[] = "1.000000000000000111022302462515654042363166809082031250000001";
    float a;
    double b;
    REQUIRE(sscanf(above, "%f", &a) == 1 && float_bits(a) == UINT32_C(0x3f800001), 43);
    REQUIRE(sscanf(above_double, "%lf", &b) == 1 && double_bits(b) == UINT64_C(0x3ff0000000000001), 44);
    rounding(FE_UPWARD);
    REQUIRE(sscanf(midpoint, "%f", &a) == 1 && float_bits(a) == UINT32_C(0x3f800001), 45);
    rounding(FE_DOWNWARD);
    REQUIRE(sscanf(midpoint, "%f", &a) == 1 && float_bits(a) == UINT32_C(0x3f800000), 46);
    return 0;
}

static int scan_fields(void)
{
    double value = 0;
    int count = -1;
    char suffix = '?';
    REQUIRE(sscanf(" 3.125 2.5XYZ", " %*f %3lf%n%c", &value, &count, &suffix) == 2
            && value == 2.5 && count == 10 && suffix == 'X', 50);
    REQUIRE(sscanf("", "%lf", &value) == EOF && value == 2.5, 51);
    REQUIRE(sscanf("Q", "%lf", &value) == 0 && value == 2.5, 52);
    return 0;
}

static int scan_prefix(void)
{
    double value = 7.0;
    int count = -1;
    struct machine_fenv before = observe();
    REQUIRE(fscanf(stdin, "%lf%n", &value, &count) == 0 && value == 7.0
            && count == -1 && fgetc(stdin) == 'Q', 55);
    struct machine_fenv after = observe();
    REQUIRE(((before.status ^ after.status) & FE_ALL_EXCEPT) == 0
            && ((before.mxcsr ^ after.mxcsr) & FE_ALL_EXCEPT) == 0, 56);
    REQUIRE(fscanf(stdin, " %lf%n", &value, &count) == 1 && count == 15
            && (double_bits(value) & UINT64_C(0x7fffffffffffffff)) > UINT64_C(0x7ff0000000000000)
            && fgetc(stdin) == '!', 57);
    return 0;
}

static int dispatch(const char *mode)
{
    if (equal(mode, "values"))
        return scan_values();
    if (equal(mode, "rounding"))
        return scan_rounding();
    if (equal(mode, "fields"))
        return scan_fields();
    if (equal(mode, "prefix"))
        return scan_prefix();
    if (equal(mode, "stdin")) {
        double a = 0;
        long double b = 0;
        REQUIRE(scanf("%lf", &a) == 1 && a == 1.5, 62);
        REQUIRE(call_vscanf("%Lf", &b) == 1 && b == -2.5L, 63);
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
