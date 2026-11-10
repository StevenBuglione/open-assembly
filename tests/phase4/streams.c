#define _GNU_SOURCE

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

#include "file.h"

static int input(void)
{
    static const unsigned char sample[] = {'a', '\n', 0xff, 'p', 'q', 'r', 's'};
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, sample, sizeof sample), 10);
    FILE *stream = fopen(file.path, "rb");
    REQUIRE(stream, 20);
    char line[12] = "untouched";
    REQUIRE(fgets(line, sizeof line, stream) == line && same(line, "a\n"), 21);
    REQUIRE(fgetc(stream) == 255, 22);
    REQUIRE(getc(stream) == 'p', 23);
    REQUIRE(ungetc('Z', stream) == 'Z', 24);
#ifndef OA_PHASE4_HOST
    REQUIRE(ungetc('Q', stream) == EOF, 25);
#endif
    REQUIRE(ungetc(EOF, stream) == EOF && fgetc(stream) == 'Z', 26);
    char bytes[5] = {0, 0, 0, 0, '!'};
    REQUIRE(fread(bytes, 2, 2, stream) == 1 && bytes_equal(bytes, "qr", 2) && bytes[4] == '!', 27);
    REQUIRE(feof(stream) && !ferror(stream), 28);
    REQUIRE(fgetc(stream) == EOF && ungetc('K', stream) == 'K'
            && !feof(stream) && fgetc(stream) == 'K', 29);
    REQUIRE(fgetc(stream) == EOF && feof(stream), 30);
    clearerr(stream);
    REQUIRE(!feof(stream) && !ferror(stream), 31);
#ifndef OA_PHASE4_HOST
    REQUIRE(fgets(line, 1, stream) == line && !line[0] && !feof(stream), 32);
    REQUIRE(!fgets(line, 0, stream) && !feof(stream), 33);
#endif
    line[0] = '!';
    REQUIRE(!fgets(line, sizeof line, stream) && feof(stream) && line[0] == '!', 34);
    REQUIRE(fclose(stream) == 0 && file_fixture_close(&file), 35);
    return 0;
}

static int output(void)
{
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, "old", 3), 10);
    FILE *stream = fopen(file.path, "wb");
    REQUIRE(stream, 20);
    char caller_buffer[32], visible[12];
    REQUIRE(setvbuf(stream, caller_buffer, _IOFBF, sizeof caller_buffer) == 0, 40);
    REQUIRE(fwrite("ab", 1, 2, stream) == 2, 41);
    REQUIRE(fputc(0x1ff, stream) == 255, 42);
    REQUIRE(putc('Z', stream) == 'Z', 43);
    REQUIRE(fputs("xy", stream) >= 0, 44);
#ifndef OA_PHASE4_HOST
    REQUIRE(file_fixture_read(&file, visible, sizeof visible) == 0, 45);
#endif
    REQUIRE(fflush(stream) == 0, 46);
    static const unsigned char expected[] = {'a', 'b', 0xff, 'Z', 'x', 'y'};
    REQUIRE(file_fixture_read(&file, visible, sizeof visible) == sizeof expected
            && bytes_equal(visible, expected, sizeof expected), 47);
    REQUIRE(fclose(stream) == 0 && file_fixture_close(&file), 48);
    return 0;
}

static int buffering(void)
{
    struct file_fixture a, b;
    REQUIRE(file_fixture_open(&a, NULL, 0) && file_fixture_open(&b, NULL, 0), 10);
    FILE *line = fopen(a.path, "w"), *immediate = fopen(b.path, "w");
    REQUIRE(line && immediate, 20);
    char caller_buffer[24], visible[24];
    REQUIRE(setvbuf(line, caller_buffer, _IOLBF, sizeof caller_buffer) == 0, 50);
    REQUIRE(fputs("aa", line) >= 0 && file_fixture_read(&a, visible, sizeof visible) == 0, 51);
    REQUIRE(fputs("b\n", line) >= 0 && file_fixture_read(&a, visible, sizeof visible) == 4
            && bytes_equal(visible, "aab\n", 4), 52);
    REQUIRE(fputc('c', line) == 'c' && file_fixture_read(&a, visible, sizeof visible) == 4, 53);
    setbuf(immediate, NULL);
    REQUIRE(fputc('D', immediate) == 'D' && file_fixture_read(&b, visible, sizeof visible) == 1
            && visible[0] == 'D', 54);
    REQUIRE(fflush(NULL) == 0 && file_fixture_read(&a, visible, sizeof visible) == 5
            && bytes_equal(visible, "aab\nc", 5), 55);
    REQUIRE(fclose(line) == 0 && fclose(immediate) == 0
            && file_fixture_close(&a) && file_fixture_close(&b), 56);
    return 0;
}

static int update(void)
{
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, "abcde", 5), 10);
    FILE *stream = fopen(file.path, "r+b");
    REQUIRE(stream, 20);
    REQUIRE(fgetc(stream) == 'a' && ftell(stream) == 1, 60);
    fpos_t saved = {0};
    REQUIRE(fgetpos(stream, &saved) == 0, 61);
    REQUIRE(fgetc(stream) == 'b' && ungetc('Q', stream) == 'Q' && ftell(stream) == 1, 62);
    REQUIRE(fseek(stream, 1, SEEK_CUR) == 0 && ftell(stream) == 2 && fgetc(stream) == 'c', 63);
    REQUIRE(fsetpos(stream, &saved) == 0 && fgetc(stream) == 'b', 64);
    REQUIRE(fseek(stream, 0, SEEK_CUR) == 0 && fputc('Z', stream) == 'Z' && ftell(stream) == 3, 65);
    REQUIRE(fflush(stream) == 0 && fgetc(stream) == 'd' && fgetc(stream) == 'e', 66);
    REQUIRE(fgetc(stream) == EOF && feof(stream), 67);
    REQUIRE(fputc('F', stream) == 'F' && fflush(stream) == 0, 68);
    rewind(stream);
    char bytes[8];
    REQUIRE(!feof(stream) && !ferror(stream) && ftell(stream) == 0
            && fread(bytes, 1, 6, stream) == 6 && bytes_equal(bytes, "abZdeF", 6), 69);
    REQUIRE(fclose(stream) == 0 && file_fixture_close(&file), 70);
    return 0;
}

static int append_reopen(void)
{
    struct file_fixture a, b;
    REQUIRE(file_fixture_open(&a, "abc", 3) && file_fixture_open(&b, "other", 5), 10);
    FILE *stream = fopen(a.path, "a+");
    REQUIRE(stream, 20);
    REQUIRE(fseek(stream, 0, SEEK_SET) == 0 && fputs("X", stream) >= 0, 71);
    REQUIRE(freopen(b.path, "rb", stream) == stream, 72);
    char bytes[8];
    REQUIRE(file_fixture_read(&a, bytes, sizeof bytes) == 4 && bytes_equal(bytes, "abcX", 4), 73);
    REQUIRE(fread(bytes, 1, 5, stream) == 5 && bytes_equal(bytes, "other", 5), 74);
    REQUIRE(fclose(stream) == 0 && file_fixture_close(&a) && file_fixture_close(&b), 75);
    return 0;
}

static int open_modes(void)
{
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, "abc", 3), 10);
    errno = 0;
    REQUIRE(!fopen(file.path, "wbx") && errno == EEXIST, 76);
    FILE *stream = fopen(file.path, "wb+");
    REQUIRE(stream, 77);
    REQUIRE(fgetc(stream) == EOF && feof(stream), 78);
    errno = 0;
    REQUIRE(!freopen(NULL, "r", stream) && errno == EINVAL, 79);
    REQUIRE(file_fixture_close(&file), 88);
    return 0;
}

static int flush_input(void)
{
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, "abc", 3), 10);
    FILE *stream = fopen(file.path, "rb");
    REQUIRE(stream, 20);
    REQUIRE(fgetc(stream) == 'a' && ungetc('X', stream) == 'X' && ftell(stream) == 0, 76);
    REQUIRE(fflush(stream) == 0 && ftell(stream) == 0, 77);
    REQUIRE(fgetc(stream) == 'a' && fgetc(stream) == 'b', 78);
    REQUIRE(fclose(stream) == 0 && file_fixture_close(&file), 79);
    return 0;
}

static int errors(void)
{
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, "R", 1), 10);
    FILE *stream = fopen(file.path, "r");
    REQUIRE(stream, 20);
    errno = 0;
    REQUIRE(fputc('Z', stream) == EOF && ferror(stream) && !feof(stream), 80);
#ifndef OA_PHASE4_HOST
    REQUIRE(errno == EBADF, 89);
#endif
    clearerr(stream);
    REQUIRE(!ferror(stream) && !feof(stream) && fgetc(stream) == 'R', 81);
    REQUIRE(fgetc(stream) == EOF && feof(stream), 82);
    REQUIRE(fputc('Z', stream) == EOF && ferror(stream), 85);
    rewind(stream);
    REQUIRE(!ferror(stream) && !feof(stream) && fgetc(stream) == 'R', 83);
    REQUIRE(fclose(stream) == 0 && file_fixture_close(&file), 84);
    return 0;
}

static int overflow(void)
{
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, "Q", 1), 10);
    FILE *stream = fopen(file.path, "r+");
    REQUIRE(stream, 20);
    char byte = '!';
    REQUIRE(fread(&byte, 0, SIZE_MAX, stream) == 0 && fwrite(&byte, SIZE_MAX, 0, stream) == 0
            && byte == '!' && ftell(stream) == 0 && !ferror(stream) && !feof(stream), 85);
    errno = 0;
    REQUIRE(fread(&byte, SIZE_MAX, 2, stream) == 0 && errno == EOVERFLOW
            && byte == '!' && ferror(stream) && ftell(stream) == 0, 86);
    clearerr(stream);
    errno = 0;
    REQUIRE(fwrite(&byte, SIZE_MAX, 2, stream) == 0 && errno == EOVERFLOW
            && ferror(stream) && ftell(stream) == 0, 87);
    REQUIRE(fclose(stream) == 0 && file_fixture_close(&file), 88);
    return 0;
}

static void goodbye(void)
{
    if (fputs("|handler", stdout) < 0)
        _Exit(93);
}

static int standard(const char *kind)
{
    if (same(kind, "get")) {
        REQUIRE(getchar() == 255 && getchar() == 'Y' && getchar() == EOF && feof(stdin), 90);
    } else if (same(kind, "close-pipe")) {
        REQUIRE(fgetc(stdin) == 'A' && fclose(stdin) == 0, 91);
        char byte;
        REQUIRE(kernel_call(__NR_read, 0, (long)&byte, 1, 0, 0, 0) == -EBADF, 92);
    } else if (same(kind, "put")) {
        REQUIRE(putchar('A') == 'A' && puts("B") >= 0, 93);
    } else if (same(kind, "exit")) {
        REQUIRE(fputs("main", stdout) >= 0 && atexit(goodbye) == 0, 94);
    } else if (same(kind, "immediate")) {
        REQUIRE(fputs("hidden", stdout) >= 0, 95);
        _Exit(7);
    } else if (same(kind, "stderr")) {
        REQUIRE(fputc('E', stderr) == 'E', 96);
        _Exit(7);
    } else if (same(kind, "perror")) {
        errno = 0;
        perror("unit");
        perror("");
        perror(NULL);
    } else {
        return 11;
    }
    return 0;
}

int main(int argc, char **argv)
{
    REQUIRE(argc == 2, 9);
    if (same(argv[1], "input"))
        return input();
    if (same(argv[1], "output"))
        return output();
    if (same(argv[1], "buffering"))
        return buffering();
    if (same(argv[1], "update"))
        return update();
    if (same(argv[1], "append"))
        return append_reopen();
    if (same(argv[1], "open-modes"))
        return open_modes();
    if (same(argv[1], "flush-input"))
        return flush_input();
    if (same(argv[1], "errors"))
        return errors();
    if (same(argv[1], "overflow"))
        return overflow();
    return standard(argv[1]);
}
