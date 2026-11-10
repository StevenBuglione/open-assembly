#include <errno.h>
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

static const char text[] = "\xce\xa9\xe4\xb8\xad\nZ";

static FILE *input(const char *bytes, size_t size)
{
    FILE *file = fopen("input", "w");
    if (!file)
        return NULL;
    size_t written = fwrite(bytes, 1, size, file);
    if (fclose(file) || written != size)
        return NULL;
    return fopen("input", "r");
}

static int orientation(void)
{
    FILE *file = input(text, sizeof text - 1);
    if (!file)
        return 90;
    int valid = fwide(file, 0) == 0 && fwide(file, 1) > 0 &&
                fwide(file, -1) > 0 && fgetwc(file) == L'\u03a9';
    if (fclose(file) || !valid)
        return 11;
    file = input("A", 1);
    if (!file)
        return 90;
    valid = fwide(file, -1) < 0 && fwide(file, 1) < 0 && fgetc(file) == 'A';
    return fclose(file) == 0 && valid ? 0 : 11;
}

static int read_file(const char *mode)
{
    FILE *file = input(text, sizeof text - 1);
    if (!file)
        return 90;
    int valid;
    if (!strcmp(mode, "fgetwc"))
        valid = fgetwc(file) == L'\u03a9' && fgetwc(file) == L'\u4e2d';
    else if (!strcmp(mode, "getwc"))
        valid = getwc(file) == L'\u03a9' && getwc(file) == L'\u4e2d';
    else if (!strcmp(mode, "fgetws")) {
        wchar_t buffer[] = {L'#', L'#', L'#', L'#', L'#'};
        valid = fgetws(buffer, 4, file) == buffer && !wcscmp(buffer, L"\u03a9\u4e2d\n") &&
                buffer[4] == L'#' && fgetwc(file) == L'Z';
    } else {
        valid = fgetwc(file) == L'\u03a9' && ungetwc(L'\u00e9', file) == L'\u00e9' &&
                fgetwc(file) == L'\u00e9' && fgetwc(file) == L'\u4e2d';
    }
    return fclose(file) == 0 && valid ? 0 : 12;
}

static int write_file(const char *mode)
{
    FILE *file = fopen("output", "w");
    if (!file)
        return 90;
    int valid;
    int string = !strcmp(mode, "fputws");
    if (string)
        valid = fputws(L"\u03a9\u4e2d\nZ", file) >= 0;
    else if (!strcmp(mode, "putwc"))
        valid = putwc(L'\u03a9', file) == L'\u03a9';
    else
        valid = fputwc(L'\u03a9', file) == L'\u03a9';
    if (fclose(file) || !valid)
        return 13;
    file = fopen("output", "r");
    if (!file)
        return 90;
    char buffer[sizeof text];
    size_t size = fread(buffer, 1, sizeof buffer, file);
    return fclose(file) == 0 && size == (string ? sizeof text - 1 : 2) &&
           !memcmp(buffer, text, size) ? 0 : 14;
}

#ifndef OA_PHASE9_HOST
static int stream_policy(void)
{
    FILE *file = input(text, sizeof text - 1);
    if (!file)
        return 90;
    errno = EDOM;
    wchar_t one = L'#';
    if (fgetws(&one, 1, file) != &one || one || fwide(file, 0) <= 0 ||
        fgetc(file) != EOF || ferror(file) || feof(file) || errno != EDOM)
        return 21;
    if (!setlocale(LC_CTYPE, "C") || fgetwc(file) != L'\u03a9' || errno != EDOM)
        return 22;
    if (ungetwc(L'Q', file) != L'Q' || ungetwc(L'R', file) != WEOF ||
        ungetwc(WEOF, file) != WEOF || fgetwc(file) != L'Q' || fgetwc(file) != L'\u4e2d')
        return 23;
    if (fgetwc(file) != L'\n' || fgetwc(file) != L'Z' || fgetwc(file) != WEOF || !feof(file) ||
        ferror(file) || ungetwc(L'X', file) != L'X' || feof(file) || fgetwc(file) != L'X')
        return 24;
    if (freopen("input", "r", file) != file || fwide(file, 0) || fgetwc(file) != WEOF ||
        errno != EILSEQ || !ferror(file))
        return 25;
    if (fclose(file) || !setlocale(LC_CTYPE, "C.UTF-8"))
        return 90;
    file = input("\xe2\x82", 2);
    if (!file)
        return 90;
    errno = EDOM;
    if (fgetwc(file) != WEOF || errno != EILSEQ || !ferror(file))
        return 26;
    return fclose(file) == 0 ? 0 : 90;
}
#endif

int main(int argc, char **argv)
{
    if (argc != 2 || !setlocale(LC_CTYPE, "C.UTF-8"))
        return 90;
    const char *mode = argv[1];
    if (!strcmp(mode, "fwide"))
        return orientation();
    if (!strcmp(mode, "fgetwc") || !strcmp(mode, "getwc") || !strcmp(mode, "fgetws") ||
        !strcmp(mode, "ungetwc"))
        return read_file(mode);
    if (!strcmp(mode, "fputwc") || !strcmp(mode, "putwc") || !strcmp(mode, "fputws"))
        return write_file(mode);
    if (!strcmp(mode, "getwchar"))
        return getwchar() == L'\u03a9' && getwchar() == L'\u4e2d' ? 0 : 15;
    if (!strcmp(mode, "putwchar"))
        return putwchar(L'\u03a9') == L'\u03a9' && fflush(stdout) == 0 ? 0 : 16;
#ifndef OA_PHASE9_HOST
    if (!strcmp(mode, "stream-policy"))
        return stream_policy();
#endif
    return 91;
}
