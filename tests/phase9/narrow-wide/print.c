#define _GNU_SOURCE
#include <errno.h>
#include <locale.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#ifndef OA_PHASE9_HOST
#include <sys/mman.h>
extern long __al_syscall(long, long, long, long, long, long, long);
#endif

static int to_file(FILE *file, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vfprintf(file, format, args);
    va_end(args);
    return result;
}

static int to_stdout(const char *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vprintf(format, args);
    va_end(args);
    return result;
}

static int to_string(char *buffer, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vsprintf(buffer, format, args);
    va_end(args);
    return result;
}

static int to_bounded(char *buffer, size_t size, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vsnprintf(buffer, size, format, args);
    va_end(args);
    return result;
}

static int to_allocated(char **buffer, const char *format, ...)
{
    va_list args;
    va_start(args, format);
    int result = vasprintf(buffer, format, args);
    va_end(args);
    return result;
}

#define FORMAT "%lc|%8.4ls%n|%02x"
#define VALUES (wint_t)L'\u03a9', L"A\u4e2dZ", &count, 0x2au
static const char expected[] = "\xce\xa9|    A\xe4\xb8\xad|2a";

static int string_output(const char *mode)
{
    char buffer[sizeof expected + 1];
    memset(buffer, '#', sizeof buffer);
    int count = -1;
    int result;
    if (!strcmp(mode, "sprintf"))
        result = sprintf(buffer, FORMAT, VALUES);
    else if (!strcmp(mode, "vsprintf"))
        result = to_string(buffer, FORMAT, VALUES);
    else if (!strcmp(mode, "snprintf"))
        result = snprintf(buffer, sizeof expected, FORMAT, VALUES);
    else if (!strcmp(mode, "vsnprintf"))
        result = to_bounded(buffer, sizeof expected, FORMAT, VALUES);
    else {
        char *allocation = NULL;
        result = to_allocated(&allocation, FORMAT, VALUES);
        int valid = result == (int)sizeof expected - 1 && allocation && count == 11 &&
                    !memcmp(allocation, expected, sizeof expected);
        free(allocation);
        return valid ? 0 : 11;
    }
    return result == (int)sizeof expected - 1 && count == 11 &&
           !memcmp(buffer, expected, sizeof expected) && buffer[sizeof expected] == '#' ? 0 : 11;
}

static int file_output(int variadic)
{
    FILE *file = fopen("output", "w+");
    if (!file)
        return 90;
    int count = -1;
    int result = variadic ? to_file(file, FORMAT, VALUES) : fprintf(file, FORMAT, VALUES);
    if (result != (int)sizeof expected - 1 || count != 11) {
        fclose(file);
        return 12;
    }
    if (fseek(file, 0, SEEK_SET))
        return 90;
    char buffer[sizeof expected];
    size_t size = fread(buffer, 1, sizeof buffer, file);
    return fclose(file) == 0 && size == sizeof expected - 1 &&
           !memcmp(buffer, expected, size) ? 0 : 13;
}

static int standard_output(int variadic)
{
    int count = -1;
    int result = variadic ? to_stdout(FORMAT, VALUES) : printf(FORMAT, VALUES);
    return result == (int)sizeof expected - 1 && count == 11 && fflush(stdout) == 0 ? 0 : 14;
}

#ifndef OA_PHASE9_HOST
static int output_policy(void)
{
    char buffer[16];
    int count = -1;
    if (snprintf(buffer, sizeof buffer, "A%lcB%n", (wint_t)0, &count) != 3 || count != 3 ||
        memcmp(buffer, "A\0B", 4))
        return 20;
    memset(buffer, '#', sizeof buffer);
    if (snprintf(buffer, 2, "%lc", (wint_t)L'\u03a9') != 2 ||
        (unsigned char)buffer[0] != 0xce || buffer[1] || buffer[2] != '#')
        return 21;
    if (snprintf(NULL, 0, "%ls", L"\u03a9\u4e2d") != 5 ||
        snprintf(buffer, sizeof buffer, "%.1ls", L"\u03a9") != 0 || buffer[0] ||
        snprintf(buffer, sizeof buffer, "%.2ls", L"\u03a9Z") != 2 ||
        memcmp(buffer, "\xce\xa9", 3))
        return 22;
    const wchar_t invalid[] = {L'A', (wchar_t)0xd800, 0};
    if (snprintf(buffer, sizeof buffer, "%.1ls", invalid) != 1 || strcmp(buffer, "A"))
        return 23;
    errno = EDOM;
    if (snprintf(buffer, sizeof buffer, "%ls", invalid) >= 0 || errno != EILSEQ)
        return 24;
    char sentinel, *allocation = &sentinel;
    errno = EDOM;
    if (to_allocated(&allocation, "%lc", (wint_t)0x110000) >= 0 || errno != EILSEQ || allocation)
        return 25;
    if (!setlocale(LC_CTYPE, "C"))
        return 90;
    errno = EDOM;
    if (snprintf(buffer, sizeof buffer, "%lc", (wint_t)L'\u03a9') >= 0 || errno != EILSEQ)
        return 26;
    return 0;
}

static int guard(void)
{
    enum { page = 4096 };
    long mapping = __al_syscall(9, 0, 2 * page, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mapping < 0 || __al_syscall(10, mapping, page, PROT_READ | PROT_WRITE, 0, 0, 0))
        return 90;
    unsigned char *storage = (void *)mapping;
    wchar_t *one = (wchar_t *)(storage + page - sizeof(wchar_t));
    *one = L'A';
    if (__al_syscall(10, (long)storage, page, PROT_READ, 0, 0, 0))
        return 90;
    char out[4] = {'#', '#', '#', '#'};
    int result = snprintf(out + 1, 2, "%.1ls", one);
    return __al_syscall(11, mapping, 2 * page, 0, 0, 0, 0) == 0 && result == 1 && out[0] == '#' && out[1] == 'A' &&
           out[2] == 0 && out[3] == '#' ? 0 : 27;
}
#endif

int main(int argc, char **argv)
{
    if (argc != 2 || !setlocale(LC_CTYPE, "C.UTF-8"))
        return 90;
    const char *mode = argv[1];
    if (!strcmp(mode, "printf"))
        return standard_output(0);
    if (!strcmp(mode, "vprintf"))
        return standard_output(1);
    if (!strcmp(mode, "fprintf"))
        return file_output(0);
    if (!strcmp(mode, "vfprintf"))
        return file_output(1);
#ifndef OA_PHASE9_HOST
    if (!strcmp(mode, "output-policy"))
        return output_policy();
    if (!strcmp(mode, "guard"))
        return guard();
#endif
    return string_output(mode);
}
