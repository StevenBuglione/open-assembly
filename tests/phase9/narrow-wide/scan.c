#include <errno.h>
#include <locale.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

static int from_file(FILE *file, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vfscanf(file, format, args);
    va_end(args);
    return result;
}

static int from_stdin(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vscanf(format, args);
    va_end(args);
    return result;
}

static int from_string(const char *buffer, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vsscanf(buffer, format, args);
    va_end(args);
    return result;
}

static const char subject[] = "Q|\xce\xa9\xe4\xb8\xad Z]BA?";
#define FORMAT "%lc|%ls %*c%3l[]A-C]%n"
#define OUTPUTS character + 1, word, set, &count

static FILE *prepare(const char *bytes, size_t size)
{
    FILE *file = fopen("input", "w+");
    if (!file)
        return NULL;
    if (fwrite(bytes, 1, size, file) != size || fseek(file, 0, SEEK_SET)) {
        fclose(file);
        return NULL;
    }
    return file;
}

static int common(const char *mode)
{
    FILE *file = NULL;
    wchar_t character[] = {L'#', L'#', L'#'}, word[] = {L'#', L'#', L'#', L'#'},
            set[] = {L'#', L'#', L'#', L'#', L'#'};
    int count = -1, result, failure;
    if (!strcmp(mode, "sscanf")) {
        result = sscanf(subject, FORMAT, OUTPUTS);
        failure = 11;
    } else if (!strcmp(mode, "vsscanf")) {
        result = from_string(subject, FORMAT, OUTPUTS);
        failure = 11;
    } else if (!strcmp(mode, "scanf")) {
        result = scanf(FORMAT, OUTPUTS);
        file = stdin;
        failure = 13;
    } else if (!strcmp(mode, "vscanf")) {
        result = from_stdin(FORMAT, OUTPUTS);
        file = stdin;
        failure = 13;
    } else {
        int variadic = !strcmp(mode, "vfscanf");
        if (!variadic && strcmp(mode, "fscanf"))
            return 91;
        file = prepare(subject, sizeof subject - 1);
        if (!file)
            return 90;
        result = variadic ? from_file(file, FORMAT, OUTPUTS) : fscanf(file, FORMAT, OUTPUTS);
        failure = 12;
    }
    int valid = result == 3 && count == 12 && character[0] == L'#' &&
                character[1] == L'Q' && character[2] == L'#' &&
                !wcscmp(word, L"\u03a9\u4e2d") && word[3] == L'#' &&
                !wcscmp(set, L"]BA") && set[4] == L'#';
    if (file) {
        if (valid && fgetc(file) != '?')
            valid = 0;
        if (file != stdin && fclose(file))
            return 92;
    }
    return valid ? 0 : failure;
}

#ifndef OA_PHASE9_HOST
static int byte_width(void)
{
    static const char omega[] = "\xce\xa9Q!";
    wchar_t out[] = {L'#', L'#', L'#', L'#'};
    int count = -1;
    if (sscanf(omega, "%2lc%n", out, &count) != 1 || count != 2 ||
        out[0] != L'\u03a9' || out[1] != L'#')
        return 20;
    if (sscanf(omega, "%3lc%n", out, &count) != 1 || count != 3 ||
        out[0] != L'\u03a9' || out[1] != L'Q' || out[2] != L'#')
        return 21;
    if (sscanf(omega, "%3ls%n", out, &count) != 1 || count != 3 ||
        wcscmp(out, L"\u03a9Q") || out[3] != L'#')
        return 22;
    if (sscanf(omega, "%3l[\xce\xa9Q]%n", out, &count) != 1 || count != 3 ||
        wcscmp(out, L"\u03a9Q") || out[3] != L'#')
        return 23;
    if (sscanf(omega, "%3l[^!]%n", out, &count) != 1 || count != 3 ||
        wcscmp(out, L"\u03a9Q"))
        return 24;
    return 0;
}

static int failures(void)
{
    wchar_t out[] = {L'#', L'#', L'#', L'#'};
    errno = EDOM;
    if (sscanf("\xce\xa9", "%lc", out) != EOF || errno != EILSEQ || out[0] != L'#')
        return 25;
    errno = EDOM;
    if (sscanf("\xe4\xb8\xad", "%2ls", out) != EOF || errno != EILSEQ || out[0] != L'#')
        return 26;
    errno = EDOM;
    if (sscanf("\xce\xa9", "%l[\xce]", out) != EOF || errno != EILSEQ || out[0] != L'#')
        return 27;
    errno = EDOM;
    int count = -1;
    if (sscanf("\xce\xa9", "%*1ls%n", &count) != EOF || errno != EILSEQ || count != -1)
        return 28;
    errno = EDOM;
    if (sscanf("Q", "%2lc", out) != EOF || out[0] != L'#' || out[1] != L'#')
        return 29;
    errno = EDOM;
    int value = -1;
    if (sscanf("19 \xf0\x80", "%d %ls", &value, out) != 1 || value != 19 ||
        errno != EILSEQ || out[0] != L'#')
        return 30;
    FILE *file = prepare("\xce\xa9Q", 3);
    if (!file)
        return 90;
    errno = EDOM;
    int valid = fscanf(file, "%1ls", out) == EOF && errno == EILSEQ && out[0] == L'#' &&
                fgetc(file) == 0xa9 && fgetc(file) == 'Q';
    return fclose(file) == 0 && valid ? 0 : 31;
}
#endif

int main(int argc, char **argv)
{
    if (argc != 2 || !setlocale(LC_CTYPE, "C.UTF-8"))
        return 90;
#ifndef OA_PHASE9_HOST
    if (!strcmp(argv[1], "byte-width"))
        return byte_width();
    if (!strcmp(argv[1], "failures"))
        return failures();
#endif
    return common(argv[1]);
}
