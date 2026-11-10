#define _GNU_SOURCE

#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>

#ifdef OA_PHASE4_HOST
# include <sys/mman.h>
#else
# include <linux/mman.h>
#endif

#include "file.h"

#define TEXT_IS(actual, result, literal) ((result) == (int)(sizeof(literal) - 1) && same(actual, literal))

/* Exercise deliberate width/flag edges through the runtime symbol. */
static int (*volatile format_probe)(char *, size_t, const char *, ...) = snprintf;

static int call_vsnprintf(char *buffer, size_t size, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = vsnprintf(buffer, size, format, arguments);
    va_end(arguments);
    return result;
}

static int call_vsprintf(char *buffer, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = vsprintf(buffer, format, arguments);
    va_end(arguments);
    return result;
}

static int call_vfprintf(FILE *stream, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = vfprintf(stream, format, arguments);
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

static int integer_va(void)
{
    char buffer[256];
    int result = call_vsnprintf(buffer, sizeof buffer, "%ld|%lld|%jd|%zu|%td|%tu|%c|%s",
                                LONG_MIN, LLONG_MAX, (intmax_t)-31, SIZE_MAX, (ptrdiff_t)-33,
                                (unsigned long)34, 'Q', "tail");
    REQUIRE(TEXT_IS(buffer, result,
                    "-9223372036854775808|9223372036854775807|-31|18446744073709551615|-33|34|Q|tail"), 21);
    return 0;
}

static int integers(void)
{
    char buffer[256];
    int result = snprintf(buffer, sizeof buffer, "%d|%i|%u|%#x|%#X|%#o|%hhd|%hhu|%hd|%hu",
                          INT_MIN, -19, UINT_MAX, 0x2au, 0x2au, 9u,
                          (signed char)-128, (unsigned char)255,
                          (short)-32768, (unsigned short)65535);
    REQUIRE(TEXT_IS(buffer, result, "-2147483648|-19|4294967295|0x2a|0X2A|011|-128|255|-32768|65535"), 20);
    return integer_va();
}

static int flags(void)
{
    char buffer[256];
    int result = format_probe(buffer, sizeof buffer, "%+06d|% 5d|%-05d|%08.4d|%#.0o|%.0d|%#.0x|%#8.4x",
                              42, 42, 42, 42, 0u, 0, 0u, 42u);
    REQUIRE(TEXT_IS(buffer, result, "+00042|   42|42   |    0042|0|||  0x002a"), 24);
    result = snprintf(buffer, sizeof buffer, "%*.*s|%.*d|%3c|%c|%%",
                      -6, 3, "abcdef", -2, 7, 0x1ff, 0);
    static const unsigned char expected[] = "abc   |7|  \xff|\0|%";
    REQUIRE(result == sizeof expected - 1 && bytes_equal(buffer, expected, sizeof expected), 25);
    return 0;
}

static int counts(void)
{
    char buffer[16];
    signed char hh = -1;
    short h = -1;
    int n = -1;
    long l = -1;
    long long ll = -1;
    intmax_t j = -1;
    long z = -1;
    ptrdiff_t t = -1;
    int result = snprintf(buffer, sizeof buffer, "A%hhnB%hnC%nD%lnE%llnF%jnG%znH%tn!",
                          &hh, &h, &n, &l, &ll, &j, &z, &t);
    REQUIRE(TEXT_IS(buffer, result, "ABCDEFGH!") && hh == 1 && h == 2 && n == 3
            && l == 4 && ll == 5 && j == 6 && z == 7 && t == 8, 27);
    n = -1;
    result = snprintf(buffer, 2, "abcdef%n?", &n);
    REQUIRE(result == 7 && n == 6 && same(buffer, "a"), 28);
    return 0;
}

static int truncation(void)
{
    char buffer[12] = "!!!!!!!!!!!";
    REQUIRE(snprintf(NULL, 0, "%s:%04u", "abc", 12u) == 8, 30);
    REQUIRE(snprintf(buffer + 1, 0, "%s:%04u", "abc", 12u) == 8 && buffer[1] == '!', 31);
    REQUIRE(snprintf(buffer + 1, 1, "%s:%04u", "abc", 12u) == 8 && !buffer[1] && buffer[2] == '!', 32);
    REQUIRE(snprintf(buffer + 1, 5, "%s:%04u", "abc", 12u) == 8
            && same(buffer + 1, "abc:") && buffer[0] == '!' && buffer[6] == '!', 33);
    REQUIRE(call_vsnprintf(buffer, 9, "%s:%04u", "abc", 12u) == 8 && same(buffer, "abc:0012"), 34);
    return 0;
}

static int variant_va(void)
{
    char buffer[96];
    int result = call_vsprintf(buffer, "%s/%d/%d/%d/%d/%d/%d", "va", 6, 5, 4, 3, 2, 1);
    REQUIRE(TEXT_IS(buffer, result, "va/6/5/4/3/2/1"), 41);
    return 0;
}

static int variants(void)
{
    char buffer[96];
    int result = sprintf(buffer, "%s/%d/%d/%d/%d/%d/%d", "args", 1, 2, 3, 4, 5, 6);
    REQUIRE(TEXT_IS(buffer, result, "args/1/2/3/4/5/6"), 40);
    return variant_va();
}

static int stream_formats(int only_va)
{
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, NULL, 0), 10);
    FILE *stream = fopen(file.path, "w");
    REQUIRE(stream, 20);
    REQUIRE(only_va || fprintf(stream, "%s:%04x", "A", 42u) == 6, 50);
    REQUIRE(call_vfprintf(stream, "%+d/%s", -7, "xy") == 5, 51);
    REQUIRE(fclose(stream) == 0, 52);
    char visible[24];
    size_t size = only_va ? 5 : 11;
    const char *expected = only_va ? "-7/xy" : "A:002a-7/xy";
    REQUIRE(file_fixture_read(&file, visible, sizeof visible) == (long)size
            && bytes_equal(visible, expected, size) && file_fixture_close(&file), 53);
    return 0;
}

static int guard_precision(void)
{
    enum { PAGE = 4096 };
    long address = kernel_call(__NR_mmap, 0, 3 * PAGE, PROT_NONE,
                               MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
    REQUIRE(address > 0, 10);
    char *page = (char *)address + PAGE;
    for (int high = 0; high <= 1; ++high) {
        REQUIRE(kernel_call(__NR_mprotect, (long)page, PAGE, PROT_READ | PROT_WRITE, 0, 0, 0) == 0, 11);
        char *data = high ? page + PAGE - 5 : page;
        for (size_t i = 0; i < 5; ++i)
            data[i] = (char)('A' + i);
        REQUIRE(kernel_call(__NR_mprotect, (long)page, PAGE, PROT_READ, 0, 0, 0) == 0, 12);
        char output[8];
        int result = snprintf(output, sizeof output, "%.*s", 5, data);
        REQUIRE(TEXT_IS(output, result, "ABCDE"), 60);
    }
    REQUIRE(kernel_call(__NR_munmap, address, 3 * PAGE, 0, 0, 0, 0) == 0, 13);
    return 0;
}

static int overflow(void)
{
    errno = 0;
    REQUIRE(format_probe(NULL, 0, "%*d", INT_MIN, 1) < 0 && errno == EOVERFLOW, 70);
    errno = 0;
    REQUIRE(format_probe(NULL, 0, "%2147483647dX", 1) < 0 && errno == EOVERFLOW, 71);
    errno = 0;
    REQUIRE(format_probe(NULL, 0, "%2147483648d", 1) < 0 && errno == EOVERFLOW, 72);
    return 0;
}

static int policy(void)
{
    char buffer[40];
    int result = snprintf(buffer, sizeof buffer, "%p:%p", (void *)0, (void *)(uintptr_t)0x1234);
    REQUIRE(TEXT_IS(buffer, result, "0x0:0x1234"), 74);
    errno = 0;
    REQUIRE(snprintf(buffer, sizeof buffer, "%ls", L"wide") < 0 && errno == EINVAL, 75);
    return 0;
}

int main(int argc, char **argv)
{
    REQUIRE(argc == 2, 9);
    if (same(argv[1], "integer"))
        return integers();
    if (same(argv[1], "vinteger"))
        return integer_va();
    if (same(argv[1], "flags"))
        return flags();
    if (same(argv[1], "counts"))
        return counts();
    if (same(argv[1], "truncation"))
        return truncation();
    if (same(argv[1], "variants"))
        return variants();
    if (same(argv[1], "vvariant"))
        return variant_va();
    if (same(argv[1], "stream") || same(argv[1], "vstream"))
        return stream_formats(same(argv[1], "vstream"));
    if (same(argv[1], "guard"))
        return guard_precision();
    if (same(argv[1], "overflow"))
        return overflow();
    if (same(argv[1], "policy"))
        return policy();
    if (same(argv[1], "stdout") || same(argv[1], "vstdout")) {
        REQUIRE(same(argv[1], "vstdout") || printf("a:%d|", 7) == 4, 76);
        REQUIRE(call_vprintf("%#x|%s", 42u, "end") == 8, 77);
        return 0;
    }
    return 11;
}
