#include <errno.h>
#include <locale.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

static int from_file(FILE *file, const wchar_t *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vfwscanf(file, format, args);
    va_end(args);
    return result;
}

static int from_stdin(const wchar_t *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vwscanf(format, args);
    va_end(args);
    return result;
}

static int from_string(const wchar_t *buffer, const wchar_t *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vswscanf(buffer, format, args);
    va_end(args);
    return result;
}

#define SUBJECT L"-37|\u03a9|xyy|2.25|11/22/33/44!"
#define FORMAT L"%d|%lc|%3l[xy]|%Lf|%d/%d/%d/%d%n"
#define OUTPUTS &number, &wide, set, &fraction, &a, &b, &c, &d, &count
static const char bytes[] = "-37|\xce\xa9|xyy|2.25|11/22/33/44!";

static int conversions(const char *mode)
{
    FILE *file = NULL;
    int number = 0, count = -1, a = 0, b = 0, c = 0, d = 0;
    long double fraction = 0;
    wchar_t wide = 0, set[] = {L'#', L'#', L'#', L'#', L'#'};
    int result, failure;
    if (!strcmp(mode, "swscanf")) {
        result = swscanf(SUBJECT, FORMAT, OUTPUTS);
        failure = 11;
    } else if (!strcmp(mode, "vswscanf")) {
        result = from_string(SUBJECT, FORMAT, OUTPUTS);
        failure = 11;
    } else if (!strcmp(mode, "wscanf")) {
        result = wscanf(FORMAT, OUTPUTS);
        file = stdin;
        failure = 13;
    } else if (!strcmp(mode, "vwscanf")) {
        result = from_stdin(FORMAT, OUTPUTS);
        file = stdin;
        failure = 13;
    } else {
        int variadic = !strcmp(mode, "vfwscanf");
        if (!variadic && strcmp(mode, "fwscanf"))
            return 91;
        FILE *output = fopen("input", "w");
        if (!output)
            return 90;
        size_t written = fwrite(bytes, 1, sizeof bytes - 1, output);
        if (fclose(output) || written != sizeof bytes - 1)
            return 90;
        file = fopen("input", "r");
        if (!file)
            return 90;
        result = variadic ? from_file(file, FORMAT, OUTPUTS) : fwscanf(file, FORMAT, OUTPUTS);
        failure = 12;
    }
    int valid = result == 8 && number == -37 && wide == L'\u03a9' &&
                !wcscmp(set, L"xyy") && set[4] == L'#' && fraction == 2.25L &&
                a == 11 && b == 22 && c == 33 && d == 44 &&
                count == (int)(sizeof SUBJECT / sizeof(wchar_t)) - 2;
    if (file) {
        if (valid && fgetwc(file) != L'!')
            valid = 0;
        if (file != stdin && fclose(file))
            return 92;
    }
    return valid ? 0 : failure;
}

#ifndef OA_PHASE9_HOST
static int boundaries(void)
{
    wchar_t wide[] = {L'#', L'#', L'#', L'#'};
    int value = 1729, count = -1;
    if (swscanf(L"", L"%d", &value) != EOF || value != 1729 ||
        swscanf(L"x", L"%d", &value) != 0 || value != 1729)
        return 20;
    if (swscanf(L"ab", L"%3lc", wide) != EOF || wide[0] != L'#' || wide[1] != L'#' || wide[2] != L'#')
        return 21;
    if (swscanf(L"\u2003-21\u20037xy!", L"%d%*d%2lc%n", &value, wide, &count) != 2 ||
        value != -21 || count != 8 || wide[0] != L'x' || wide[1] != L'y' || wide[2] != L'#')
        return 22;
    char narrow[] = {'#', '#', '#', '#', '#', '#'};
    if (swscanf(L"\u03a9z!", L"%2c%n", narrow, &count) != 1 || count != 2 ||
        memcmp(narrow, "\xce\xa9z", 3) || narrow[3] != '#')
        return 23;
    if (swscanf(L"]BA?", L"%3l[]A-C]%n", wide, &count) != 1 || count != 3 || wcscmp(wide, L"]BA"))
        return 24;
    return 0;
}
#endif

int main(int argc, char **argv)
{
    if (argc != 2 || !setlocale(LC_CTYPE, "C.UTF-8"))
        return 90;
#ifndef OA_PHASE9_HOST
    if (!strcmp(argv[1], "boundaries"))
        return boundaries();
#endif
    return conversions(argv[1]);
}
