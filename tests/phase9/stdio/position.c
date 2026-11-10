#include <errno.h>
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

extern long __real___al_stdio_io(long, long, void *, size_t);
static int read_until_failure;
static int failure_fd = -1;

long __wrap___al_stdio_io(long op, long fd, void *bytes, size_t count)
{
    if (op == 0 && fd == failure_fd && read_until_failure && --read_until_failure == 0) {
        errno = EAGAIN;
        return -1;
    }
    return __real___al_stdio_io(op, fd, bytes, count);
}

static FILE *prepare(const wchar_t *text)
{
    FILE *file = tmpfile();
    if (!file)
        return NULL;
    if (!setvbuf(file, NULL, _IONBF, 0) && fputws(text, file) >= 0 && !fseek(file, 0, SEEK_SET))
        return file;
    fclose(file);
    return NULL;
}

static int basic_position(void)
{
    FILE *file = prepare(L"12\u20ac!");
    if (!file)
        return 90;
    int value = -1, count = -1;
    fpos_t position;
    if (fwscanf(file, L"%d%n", &value, &count) != 1 || value != 12 || count != 2 ||
        ftell(file) != 2 || fgetpos(file, &position))
        return 11;
    if (ungetwc(L'Q', file) != L'Q' || fwscanf(file, L"%d", &value) != 0 || value != 12 ||
        ftell(file) != 2 || fgetwc(file) != L'Q' || fgetwc(file) != L'\u20ac' || ftell(file) != 5)
        return 12;
    if (fsetpos(file, &position) || ftell(file) != 2 || fgetwc(file) != L'\u20ac' ||
        fgetwc(file) != L'!')
        return 13;
    if (fseek(file, 0, SEEK_SET) || fwscanf(file, L"%d", &value) != 1 ||
        fflush(file) || ftell(file) != 2 || fgetwc(file) != L'\u20ac')
        return 14;
    return fclose(file) == 0 ? 0 : 90;
}

static int resumed_position(void)
{
    FILE *file = prepare(L"\u20ac!");
    if (!file)
        return 90;
    failure_fd = fileno(file);
    if (failure_fd < 0)
        return 90;
    read_until_failure = 2;
    errno = EDOM;
    if (fgetwc(file) != WEOF || errno != EAGAIN || !ferror(file) || feof(file) ||
        read_until_failure || ftell(file) != 1)
        return 21;
    failure_fd = -1;
    clearerr(file);
    int value = -1;
    fpos_t position;
    if (fwscanf(file, L"%d", &value) != 0 || value != -1 || ferror(file) ||
        ftell(file) != 1 || fgetpos(file, &position))
        return 22;
    if (fgetwc(file) != L'\u20ac' || ftell(file) != 3 || fseek(file, 0, SEEK_SET) ||
        fsetpos(file, &position) || ftell(file) != 1 || fgetwc(file) != L'\u20ac' ||
        ftell(file) != 3 || fgetwc(file) != L'!')
        return 23;
    return fclose(file) == 0 ? 0 : 90;
}

int main(int argc, char **argv)
{
    if (argc != 2 || !setlocale(LC_CTYPE, "C.UTF-8"))
        return 90;
    if (!strcmp(argv[1], "position"))
        return basic_position();
    if (!strcmp(argv[1], "resumed"))
        return resumed_position();
    return 91;
}
