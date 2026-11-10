#if defined(OA_PHASE6_HOST) && !defined(_GNU_SOURCE)
# define _GNU_SOURCE
#endif

#include <errno.h>
#include <float.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

_Static_assert(DBL_MANT_DIG == 53 && LDBL_MANT_DIG == 64, "x86 floating formats");

static int render(char **result, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int count = vasprintf(result, format, arguments);
    va_end(arguments);
    return count;
}

static int same_text(const char *a, const char *b)
{
    while (*a && *a == *b) {
        ++a;
        ++b;
    }
    return *a == *b;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    char *output = NULL;
    int count = -1;
    int length;
    const char *expected;
    int prefix;
    errno = 947;
    if (same_text(argv[1], "common")) {
        length = render(&output, "%+.2f|%.3Lf%n|%u", -1.125, 2.5L, &count, 7U);
        expected = "-1.12|2.500|7";
        prefix = 11;
    } else if (same_text(argv[1], "precision")) {
        /* 1 + 2^-63 is one x87 extended step above 1. */
        const long double extended = 0x1.0000000000000002p0L;
        length = render(&output, "%.2f|%.20Lf%n|%u", 1.125, extended, &count, 7U);
        expected = "1.12|1.00000000000000000011|7";
        prefix = 27;
    } else {
        return 2;
    }
    if (length != prefix + 2 || count != prefix || !output ||
        !same_text(output, expected) || errno != 947)
        return 20;
    free(output);
    return 0;
}
