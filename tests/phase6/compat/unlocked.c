#include "../kernel_abi.h"
#include <stdio.h>

#undef getc_unlocked
#undef ferror_unlocked
#undef fputs_unlocked
#undef putchar_unlocked

static int get_case(void)
{
    int fd = (int)raw_open(AT_FDCWD, "input", O_WRONLY | O_CREAT | O_EXCL, 0600);
    const unsigned char bytes[] = {0xff, 0, 'X'};
    if (fd < 0 || raw_write(fd, bytes, sizeof bytes) != sizeof bytes || raw_close(fd))
        return 10;
    FILE *file = fopen("input", "r");
    if (!file)
        return 11;
    if (getc_unlocked(file) != 0xff || getc_unlocked(file) != 0 ||
        getc_unlocked(file) != 'X' || getc_unlocked(file) != EOF || !feof(file))
        return 12;
    return fclose(file) || raw_unlink("input", 0) ? 13 : 0;
}

static int error_case(void)
{
    FILE *file = fopen("output", "w");
    if (!file || ferror_unlocked(file))
        return 20;
    if (fgetc(file) != EOF || !ferror_unlocked(file))
        return 21;
    clearerr(file);
    if (ferror_unlocked(file))
        return 22;
    return fclose(file) || raw_unlink("output", 0) ? 23 : 0;
}

static int puts_case(void)
{
    FILE *file = fopen("output", "w");
    if (!file)
        return 30;
    if (fputs_unlocked("abc", file) < 0 || fputs_unlocked("", file) < 0 || fclose(file))
        return 31;
    int fd = (int)raw_open(AT_FDCWD, "output", O_RDONLY, 0);
    char got[4] = {0};
    if (fd < 0 || raw_read(fd, got, sizeof got) != 3 || !same_text(got, "abc"))
        return 32;
    return raw_close(fd) || raw_unlink("output", 0) ? 33 : 0;
}

static int put_case(void)
{
    return putchar_unlocked(0x155) != 'U' ? 41 : 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    if (same_text(argv[1], "get")) return get_case();
    if (same_text(argv[1], "error")) return error_case();
    if (same_text(argv[1], "puts")) return puts_case();
    if (same_text(argv[1], "put")) return put_case();
    return 2;
}
