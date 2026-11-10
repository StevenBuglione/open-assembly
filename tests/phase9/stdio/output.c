#include <errno.h>
#include <locale.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

static int to_file(FILE *file, const wchar_t *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vfwprintf(file, format, args);
    va_end(args);
    return result;
}

static int to_stdout(const wchar_t *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vwprintf(format, args);
    va_end(args);
    return result;
}

static int to_string(wchar_t *buffer, size_t capacity, const wchar_t *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vswprintf(buffer, capacity, format, args);
    va_end(args);
    return result;
}

#define FORMAT L"%d|%.1f|%.2Lf|%lc|%ls%n|%02x|%d/%d/%d/%d/%d"
#define VALUES -37, 0.5, 2.25L, (wint_t)L'\u03a9', L"\u4e2d", &count, 0x2au, 1, 2, 3, 4, 5
static const wchar_t expected[] = L"-37|0.5|2.25|\u03a9|\u4e2d|2a|1/2/3/4/5";
static const char bytes[] = "-37|0.5|2.25|\xce\xa9|\xe4\xb8\xad|2a|1/2/3/4/5";
#define WIDE_COUNT ((int)(sizeof expected / sizeof expected[0]) - 1)

static int strings(int variadic)
{
    wchar_t buffer[64];
    wmemset(buffer, L'#', sizeof buffer / sizeof buffer[0]);
    int count = -1;
    int result = variadic ? to_string(buffer, WIDE_COUNT + 1, FORMAT, VALUES)
                          : swprintf(buffer, WIDE_COUNT + 1, FORMAT, VALUES);
    return result == WIDE_COUNT && count == 16 && !wcscmp(buffer, expected) &&
           buffer[WIDE_COUNT + 1] == L'#' ? 0 : 11;
}

static int streams(int variadic)
{
    FILE *file = fopen("output", "w");
    if (!file)
        return 90;
    int count = -1;
    int result = variadic ? to_file(file, FORMAT, VALUES) : fwprintf(file, FORMAT, VALUES);
    int status = fclose(file);
    if (result != WIDE_COUNT || count != 16 || status)
        return 12;
    file = fopen("output", "r");
    if (!file)
        return 91;
    char buffer[sizeof bytes];
    size_t size = fread(buffer, 1, sizeof buffer, file);
    status = fclose(file);
    return size == sizeof bytes - 1 && !memcmp(buffer, bytes, size) && !status ? 0 : 13;
}

static int standard_output(int variadic)
{
    int count = -1;
    int result = variadic ? to_stdout(FORMAT, VALUES) : wprintf(FORMAT, VALUES);
    return result == WIDE_COUNT && count == 16 && fflush(stdout) == 0 ? 0 : 14;
}

#ifndef OA_PHASE9_HOST
static int truncated(void)
{
    for (int variadic = 0; variadic < 2; ++variadic) {
        wchar_t box[8];
        wmemset(box, L'#', sizeof box / sizeof box[0]);
        int result = variadic ? to_string(box + 1, 4, L"\u03a9%ls", L"2345")
                              : swprintf(box + 1, 4, L"\u03a9%ls", L"2345");
        if (result >= 0 || box[0] != L'#' || box[5] != L'#' || wcscmp(box + 1, L"\u03a923"))
            return 20;
        result = variadic ? to_string(box + 1, 1, L"\u03a9") : swprintf(box + 1, 1, L"\u03a9");
        if (result >= 0 || box[1] != L'\0' || box[2] != L'2')
            return 21;
        if ((variadic ? to_string(NULL, 0, L"%d", 7) : swprintf(NULL, 0, L"%d", 7)) >= 0)
            return 22;
        errno = EDOM;
        result = variadic ? to_string(box + 1, 4, L"a%s", "\xff") : swprintf(box + 1, 4, L"a%s", "\xff");
        if (result >= 0 || errno != EILSEQ || box[0] != L'#' || box[5] != L'#' ||
            box[1] != L'a' || box[2] != L'\0')
            return 23;
    }
    return 0;
}
#endif

int main(int argc, char **argv)
{
    if (argc != 2 || !setlocale(LC_CTYPE, "C.UTF-8"))
        return 90;
    if (!strcmp(argv[1], "swprintf"))
        return strings(0);
    if (!strcmp(argv[1], "vswprintf"))
        return strings(1);
    if (!strcmp(argv[1], "fwprintf"))
        return streams(0);
    if (!strcmp(argv[1], "vfwprintf"))
        return streams(1);
    if (!strcmp(argv[1], "wprintf"))
        return standard_output(0);
    if (!strcmp(argv[1], "vwprintf"))
        return standard_output(1);
#ifndef OA_PHASE9_HOST
    if (!strcmp(argv[1], "truncated"))
        return truncated();
#endif
    return 91;
}
