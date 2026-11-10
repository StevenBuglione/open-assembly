#define _GNU_SOURCE
#ifdef OA_PHASE6_HOST
#define OA_PHASE4_HOST
#endif

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

#include "../phase4/file.h"

#undef feof
#undef ferror
#undef clearerr
#undef fileno

static const unsigned char sample[] = {0, 0xff, 'R'};

static FILE *open_fixture(struct file_fixture *file, const char *mode)
{
    return file_fixture_open(file, sample, sizeof sample) ? fopen(file->path, mode) : NULL;
}

static int finish(FILE *stream, const struct file_fixture *file)
{
    return fclose(stream) == 0 && file_fixture_close(file) ? 0 : 91;
}

static int end_indicator(void)
{
    struct file_fixture file;
    FILE *stream = open_fixture(&file, "rb");
    REQUIRE(stream, 90);
    errno = EDOM;
    REQUIRE(!feof(stream) && errno == EDOM, 12);
    unsigned char output[sizeof sample];
    REQUIRE(fread(output, 1, sizeof output, stream) == sizeof output &&
            bytes_equal(output, sample, sizeof output) && !feof(stream) && !ferror(stream), 13);
    REQUIRE(fgetc(stream) == EOF, 14);
    errno = EDOM;
    REQUIRE(feof(stream) && !ferror(stream) && errno == EDOM, 11);
    REQUIRE(fgetc(stream) == EOF && feof(stream), 15);
    REQUIRE(ungetc(0, stream) == 0 && !feof(stream) && fgetc(stream) == 0, 16);
    REQUIRE(fgetc(stream) == EOF && feof(stream), 17);
    REQUIRE(fseek(stream, 0, SEEK_SET) == 0 && !feof(stream) && fgetc(stream) == sample[0], 18);
    return finish(stream, &file);
}

static int error_indicator(void)
{
    struct file_fixture file;
    FILE *stream = open_fixture(&file, "rb");
    REQUIRE(stream, 90);
    errno = EDOM;
    REQUIRE(!ferror(stream) && errno == EDOM, 12);
    REQUIRE(fputc('X', stream) == EOF, 13);
    errno = EDOM;
    REQUIRE(ferror(stream) && !feof(stream) && errno == EDOM, 11);
    REQUIRE(fgetc(stream) == sample[0] && ferror(stream), 14);
    REQUIRE(fseek(stream, 0, SEEK_END) == 0 && fgetc(stream) == EOF &&
            ferror(stream) && feof(stream), 15);
    REQUIRE(fseek(stream, 0, SEEK_SET) == 0 && ferror(stream) && !feof(stream), 16);
    clearerr(stream);
    REQUIRE(!ferror(stream) && !feof(stream) && fgetc(stream) == sample[0], 17);
    REQUIRE(fputc('Y', stream) == EOF && ferror(stream), 18);
    rewind(stream);
    REQUIRE(!ferror(stream) && !feof(stream) && fgetc(stream) == sample[0], 19);
    return finish(stream, &file);
}

static int clearing(void)
{
    struct file_fixture file;
    FILE *stream = open_fixture(&file, "rb");
    REQUIRE(stream, 90);
    REQUIRE(fseek(stream, 0, SEEK_END) == 0 && fgetc(stream) == EOF &&
            fputc('X', stream) == EOF && feof(stream) && ferror(stream), 92);
    errno = EDOM;
    clearerr(stream);
    REQUIRE(!feof(stream) && !ferror(stream) && errno == EDOM, 11);
    REQUIRE(ftell(stream) == (long)sizeof sample && fgetc(stream) == EOF && feof(stream), 12);
    clearerr(stream);
    REQUIRE(!feof(stream) && !ferror(stream), 13);

    REQUIRE(fseek(stream, 0, SEEK_SET) == 0 && fgetc(stream) == sample[0] &&
            fputc('Y', stream) == EOF && ferror(stream) && ungetc(0xa5, stream) == 0xa5, 93);
    errno = EDOM;
    clearerr(stream);
    REQUIRE(!feof(stream) && !ferror(stream) && errno == EDOM && ftell(stream) == 0 &&
            fgetc(stream) == 0xa5 && fgetc(stream) == sample[1], 14);
    REQUIRE(fclose(stream) == 0, 91);

    FILE *update = fopen(file.path, "r+b");
    char buffer[64];
    REQUIRE(update && setvbuf(update, buffer, _IOFBF, sizeof buffer) == 0 &&
            fputc('K', update) == 'K' && ftell(update) == 1, 94);
    unsigned char bytes[sizeof sample];
    REQUIRE(file_fixture_read(&file, bytes, sizeof bytes) == (long)sizeof bytes &&
            bytes_equal(bytes, sample, sizeof bytes), 95);
    errno = EDOM;
    clearerr(update);
    REQUIRE(errno == EDOM && !feof(update) && !ferror(update) && ftell(update) == 1 &&
            file_fixture_read(&file, bytes, sizeof bytes) == (long)sizeof bytes &&
            bytes_equal(bytes, sample, sizeof bytes), 15);
    REQUIRE(fflush(update) == 0 && file_fixture_read(&file, bytes, sizeof bytes) == (long)sizeof bytes &&
            bytes[0] == 'K' && bytes[1] == sample[1] && bytes[2] == sample[2], 16);
    return finish(update, &file);
}

static int descriptor(void)
{
    errno = EDOM;
    REQUIRE(fileno(stderr) == STDERR_FILENO && errno == EDOM, 11);
    REQUIRE(fileno(stdout) == STDOUT_FILENO && fileno(stdin) == STDIN_FILENO && errno == EDOM, 12);
    struct file_fixture file;
    FILE *stream = open_fixture(&file, "rb");
    REQUIRE(stream && fgetc(stream) == sample[0] && ungetc('P', stream) == 'P', 90);
    long logical = ftell(stream);
    errno = EDOM;
    int fd = fileno(stream);
    REQUIRE(fd >= 0 && fd != file.fd && errno == EDOM && logical == 0 && ftell(stream) == logical, 13);
    unsigned char bytes[sizeof sample];
    REQUIRE(kernel_call(__NR_pread64, fd, (long)bytes, sizeof bytes, 0, 0, 0) == (long)sizeof bytes &&
            bytes_equal(bytes, sample, sizeof bytes) &&
            (kernel_call(__NR_fcntl, fd, F_GETFL, 0, 0, 0, 0) & O_ACCMODE) == O_RDONLY, 14);
    long raw = kernel_call(__NR_lseek, fd, 0, SEEK_CUR, 0, 0, 0);
    REQUIRE(raw >= 0, 93);
    flockfile(stream);
    flockfile(stream);
    errno = EDOM;
    int nested = fileno(stream);
    int saved_errno = errno;
    funlockfile(stream);
    funlockfile(stream);
    REQUIRE(nested == fd && saved_errno == EDOM && ftell(stream) == logical &&
            kernel_call(__NR_lseek, fd, 0, SEEK_CUR, 0, 0, 0) == raw, 15);
    REQUIRE(fgetc(stream) == 'P' && fgetc(stream) == sample[1] && fgetc(stream) == sample[2] &&
            fgetc(stream) == EOF && fputc('Y', stream) == EOF && feof(stream) && ferror(stream), 94);
    errno = EDOM;
    REQUIRE(fileno(stream) == fd && errno == EDOM && feof(stream) && ferror(stream) &&
            ftell(stream) == (long)sizeof sample, 16);
    REQUIRE(fclose(stream) == 0, 91);
    REQUIRE(kernel_call(__NR_fcntl, fd, F_GETFD, 0, 0, 0, 0) == -EBADF &&
            file_fixture_read(&file, bytes, sizeof bytes) == (long)sizeof bytes &&
            bytes_equal(bytes, sample, sizeof bytes), 17);
    return file_fixture_close(&file) ? 0 : 91;
}

int main(int argc, char **argv)
{
    REQUIRE(argc == 2, 96);
    if (same(argv[1], "feof")) return end_indicator();
    if (same(argv[1], "ferror")) return error_indicator();
    if (same(argv[1], "clearerr")) return clearing();
    if (same(argv[1], "fileno")) return descriptor();
    return 97;
}
