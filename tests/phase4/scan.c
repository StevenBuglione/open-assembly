#define _GNU_SOURCE

#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>

#include "file.h"

static int call_vsscanf(const char *input, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = vsscanf(input, format, arguments);
    va_end(arguments);
    return result;
}

static int call_vfscanf(FILE *stream, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = vfscanf(stream, format, arguments);
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

static int integer_va(void)
{
    static const char long_text[] = "-9223372036854775808 18446744073709551615 -7 8 9 -10 11";
    long long ll = 0;
    unsigned long long ull = 0;
    intmax_t j = 0;
    uintmax_t uj = 0;
    size_t z = 0;
    ptrdiff_t t = 0;
    unsigned long ut = 0;
    int n = -1;
    int result = call_vsscanf(long_text, "%lld %llu %jd %ju %zu %td %tu%n", &ll, &ull, &j, &uj,
                              &z, &t, &ut, &n);
    REQUIRE(result == 7 && ll == LLONG_MIN && ull == ULLONG_MAX && j == -7 && uj == 8
            && z == 9 && t == -10 && ut == 11 && n == sizeof long_text - 1, 21);
    return 0;
}

static int integers(void)
{
    static const char text[] = " -128 255 -32768 65535 -2147483648 4294967295 017 -0x2A +27 fF 77";
    signed char hh = 0;
    unsigned char uh = 0;
    short h = 0;
    unsigned short us = 0;
    int d = 0, octal = 0, hex = 0, n = -1;
    unsigned int u = 0, xu = 0, ou = 0;
    long l = 0;
    int result = sscanf(text, "%hhd %hhu %hd %hu %d %u %i %i %ld %X %o%n",
                        &hh, &uh, &h, &us, &d, &u, &octal, &hex, &l, &xu, &ou, &n);
    REQUIRE(result == 11 && hh == -128 && uh == 255 && h == -32768 && us == 65535
            && d == INT_MIN && u == UINT_MAX && octal == 15 && hex == -42 && l == 27
            && xu == 255 && ou == 63 && n == sizeof text - 1, 20);

    REQUIRE(sscanf("-1", "%u", &u) == 1 && u == UINT_MAX, 22);
    return integer_va();
}

static int text(void)
{
    static const char input[] = "skip -009 Cat Z! ]? abc9";
    char word[6] = "!!!!!", characters[4] = "!!!";
    char brackets[5] = "!!!!", letters[6] = "!!!!!";
    int value = 0, n = -1;
    int result = sscanf(input, "%*4[a-z] %4d %3s %2c %2[]?] %3[^0-9]%n",
                        &value, word, characters, brackets, letters, &n);
    REQUIRE(result == 5 && value == -9 && same(word, "Cat") && word[4] == '!'
            && bytes_equal(characters, "Z!!", 3) && same(brackets, "]?")
            && same(letters, "abc") && n == sizeof input - 2, 25);
    REQUIRE(sscanf(" %", "%c%%%n", characters, &n) == 1 && characters[0] == ' ' && n == 2, 26);
    REQUIRE(sscanf("xy!", "%2[xy]", letters) == 1 && same(letters, "xy"), 27);
    return 0;
}

static int counts(void)
{
    signed char hh = -1;
    short h = -1;
    int n = -1, d = 0;
    long l = -1;
    long long ll = -1;
    intmax_t j = -1;
    long z = -1;
    ptrdiff_t t = -1;
    int result = sscanf("abcdefghi 17", "a%hhnb%hnc%nd%lne%llnf%jng%znh%tni %d",
                        &hh, &h, &n, &l, &ll, &j, &z, &t, &d);
    REQUIRE(result == 1 && d == 17 && hh == 1 && h == 2 && n == 3 && l == 4
            && ll == 5 && j == 6 && z == 7 && t == 8, 30);
    return 0;
}

static int status(void)
{
    int first = 71, second = 72, n = -1;
    REQUIRE(sscanf("", "%d", &first) == EOF && first == 71, 40);
    REQUIRE(sscanf("x", "%d", &first) == 0 && first == 71, 41);
    REQUIRE(sscanf("42", "%d%d", &first, &second) == 1 && first == 42 && second == 72, 42);
    REQUIRE(sscanf("", "%n", &n) == 0 && n == 0, 43);
    REQUIRE(sscanf("q", "x%d", &first) == 0 && first == 42, 44);
    return 0;
}

static int incomplete(void)
{
    int value = 71, n = -1;
    REQUIRE(sscanf("42", "%*d%d", &value) == 0 && value == 71, 45);
    REQUIRE(sscanf("", "%n%d", &n, &value) == 0 && n == 0 && value == 71, 46);
    char bytes[5] = "!!!!";
    n = -1;
    REQUIRE(sscanf("ab", "%3c%n", bytes, &n) <= 0 && n == -1 && bytes[3] == '!', 47);
    REQUIRE(sscanf("", "%3c%n", bytes, &n) == EOF && n == -1, 48);
    return 0;
}

static int stream_input(int only_va)
{
    static const char sample[] = "42;  +017 tail!";
    size_t prefix = only_va ? 3 : 0;
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, sample + prefix, sizeof sample - 1 - prefix), 10);
    FILE *stream = fopen(file.path, "r");
    REQUIRE(stream, 19);
    int value = 0, n = -1;
    REQUIRE(only_va || (fscanf(stream, "%d%n", &value, &n) == 1 && value == 42 && n == 2
                        && fgetc(stream) == ';'), 50);
    char word[5];
    REQUIRE(call_vfscanf(stream, " %i %4[a-z]%n", &value, word, &n) == 2
            && value == 15 && same(word, "tail") && n == 11 && fgetc(stream) == '!', 51);
    REQUIRE(fscanf(stream, "%d", &value) == EOF && feof(stream), 52);
    REQUIRE(fclose(stream) == 0 && file_fixture_close(&file), 53);
    return 0;
}

static int prefix(void)
{
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, "0xZ +! 09", 9), 10);
    FILE *stream = fopen(file.path, "r");
    REQUIRE(stream, 19);
    int value = 71;
    REQUIRE(fscanf(stream, "%i", &value) == 0 && value == 71 && fgetc(stream) == 'Z', 56);
    REQUIRE(fscanf(stream, "%d", &value) == 0 && value == 71 && fgetc(stream) == '!', 57);
    REQUIRE(fscanf(stream, "%i", &value) == 1 && value == 0 && fgetc(stream) == '9', 58);
    REQUIRE(fclose(stream) == 0 && file_fixture_close(&file), 59);
    return 0;
}

static int policy(void)
{
    void *pointer = NULL;
    int n = -1;
    REQUIRE(sscanf("0x1234!", "%p%n", &pointer, &n) == 1
            && (uintptr_t)pointer == UINT64_C(0x1234) && n == 6, 60);
    wchar_t character = L'!';
    errno = 0;
    int result = sscanf("a", "%lc", &character);
    REQUIRE(result == 1 && errno == 0 && character == L'a', 61);
    return 0;
}

int main(int argc, char **argv)
{
    REQUIRE(argc == 2, 9);
    if (same(argv[1], "integer"))
        return integers();
    if (same(argv[1], "vinteger"))
        return integer_va();
    if (same(argv[1], "text"))
        return text();
    if (same(argv[1], "counts"))
        return counts();
    if (same(argv[1], "status"))
        return status();
    if (same(argv[1], "incomplete"))
        return incomplete();
    if (same(argv[1], "stream") || same(argv[1], "vstream"))
        return stream_input(same(argv[1], "vstream"));
    if (same(argv[1], "prefix"))
        return prefix();
    if (same(argv[1], "policy"))
        return policy();
    if (same(argv[1], "stdin") || same(argv[1], "vstdin")) {
        unsigned int u = 0;
        int n = -1, d = 0;
        char c = '?';
        REQUIRE(same(argv[1], "vstdin") || (scanf("%u %n", &u, &n) == 1 && u == 17 && n == 5), 70);
        REQUIRE(call_vscanf("%c%d", &c, &d) == 2 && c == 'X' && d == -42, 71);
        return 0;
    }
    return 11;
}
