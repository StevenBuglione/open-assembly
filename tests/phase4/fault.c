#include <errno.h>
#include <stdio.h>

#include "file.h"

long __real___al_syscall(long number, long a1, long a2, long a3, long a4, long a5, long a6);

enum mode { OFF, RETRY_READ, RETRY_WRITE, PARTIAL_ERROR, HARD_ERROR, ONE_STREAM, WATCH_SEEK };
static enum mode injection;
static unsigned injected_interrupt, injected_error, shortened, seek_attempts;
static long failed_fd = -1;
static size_t limit;

long __wrap___al_syscall(long number, long a1, long a2, long a3, long a4, long a5, long a6)
{
    if (injection == WATCH_SEEK && number == __NR_lseek && a1 == 0)
        ++seek_attempts;
    int selected = injection == RETRY_READ ? number == __NR_read
                 : injection != OFF && injection != WATCH_SEEK && number == __NR_write;
    if (selected && a2 && a3 > 0) {
        if ((injection == RETRY_READ || injection == RETRY_WRITE) && !injected_interrupt) {
            ++injected_interrupt;
            return -EINTR;
        }
        if (injection == HARD_ERROR || (injection == PARTIAL_ERROR && shortened)
                || (injection == ONE_STREAM && (failed_fd == -1 || a1 == failed_fd))) {
            failed_fd = a1;
            ++injected_error;
            return -EIO;
        }
        if (!shortened && limit && (size_t)a3 > limit) {
            ++shortened;
            a3 = (long)limit;
        }
    }
    return __real___al_syscall(number, a1, a2, a3, a4, a5, a6);
}

static int read_retry(void)
{
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, "abcdefgh", 8), 10);
    FILE *stream = fopen(file.path, "r");
    REQUIRE(stream, 20);
    char buffer[24], result[8];
    REQUIRE(setvbuf(stream, buffer, _IOFBF, sizeof buffer) == 0, 21);
    injection = RETRY_READ;
    limit = 2;
    size_t count = fread(result, 1, sizeof result, stream);
    injection = OFF;
    REQUIRE(injected_interrupt == 1 && shortened == 1 && !injected_error, 22);
    REQUIRE(count == sizeof result && bytes_equal(result, "abcdefgh", sizeof result)
            && !ferror(stream) && fgetc(stream) == EOF && feof(stream), 23);
    REQUIRE(fclose(stream) == 0 && file_fixture_close(&file), 24);
    return 0;
}

static int write_retry(void)
{
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, NULL, 0), 10);
    FILE *stream = fopen(file.path, "w");
    REQUIRE(stream, 20);
    REQUIRE(fputs("abcdef", stream) >= 0, 30);
    injection = RETRY_WRITE;
    limit = 2;
    int result = fflush(stream);
    injection = OFF;
    REQUIRE(injected_interrupt == 1 && shortened == 1 && !injected_error, 31);
    REQUIRE(result == 0 && !ferror(stream), 32);
    char bytes[8];
    REQUIRE(file_fixture_read(&file, bytes, sizeof bytes) == 6 && bytes_equal(bytes, "abcdef", 6), 33);
    REQUIRE(fclose(stream) == 0 && file_fixture_close(&file), 34);
    return 0;
}

static int recover(void)
{
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, NULL, 0), 10);
    FILE *stream = fopen(file.path, "w");
    REQUIRE(stream, 20);
    REQUIRE(fwrite("ABCDE", 1, 5, stream) == 5, 40);
    injection = PARTIAL_ERROR;
    limit = 2;
    errno = 0;
    int result = fflush(stream);
    injection = OFF;
    REQUIRE(shortened == 1 && injected_error && !injected_interrupt, 41);
    REQUIRE(result == EOF && errno == EIO && ferror(stream), 42);
    char bytes[8];
    REQUIRE(file_fixture_read(&file, bytes, sizeof bytes) == 2 && bytes_equal(bytes, "AB", 2), 43);
    clearerr(stream);
    REQUIRE(!ferror(stream) && fflush(stream) == 0, 44);
    REQUIRE(file_fixture_read(&file, bytes, sizeof bytes) == 5 && bytes_equal(bytes, "ABCDE", 5), 45);
    REQUIRE(fclose(stream) == 0 && file_fixture_close(&file), 46);
    return 0;
}

static int close_failure(void)
{
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, NULL, 0), 10);
    FILE *stream = fopen(file.path, "w");
    REQUIRE(stream, 20);
    REQUIRE(fputs("abc", stream) >= 0, 50);
    injection = HARD_ERROR;
    errno = 0;
    int result = fclose(stream);
    injection = OFF;
    REQUIRE(injected_error && result == EOF && errno == EIO && failed_fd >= 0, 51);
    REQUIRE(kernel_call(__NR_close, failed_fd, 0, 0, 0, 0, 0) == -EBADF, 52);
    REQUIRE(file_fixture_close(&file), 53);
    return 0;
}

static int close_pipe(void)
{
    REQUIRE(fgetc(stdin) == 'A', 55);
    injection = WATCH_SEEK;
    int result = fclose(stdin);
    injection = OFF;
    REQUIRE(result == 0 && !seek_attempts, 56);
    REQUIRE(kernel_call(__NR_close, 0, 0, 0, 0, 0, 0) == -EBADF, 57);
    return 0;
}

static int partial_element(void)
{
    struct file_fixture file;
    REQUIRE(file_fixture_open(&file, NULL, 0), 10);
    FILE *stream = fopen(file.path, "w");
    REQUIRE(stream, 20);
    REQUIRE(setvbuf(stream, NULL, _IONBF, 0) == 0, 60);
    injection = PARTIAL_ERROR;
    limit = 3;
    errno = 0;
    size_t count = fwrite("ABCDEFGH", 2, 4, stream);
    injection = OFF;
    REQUIRE(shortened == 1 && injected_error && count == 1 && errno == EIO && ferror(stream), 61);
    char bytes[9];
    REQUIRE(file_fixture_read(&file, bytes, sizeof bytes) == 3 && bytes_equal(bytes, "ABC", 3), 62);
    REQUIRE(fclose(stream) == 0 && file_fixture_close(&file), 63);
    return 0;
}

static int flush_all_failure(void)
{
    struct file_fixture a, b;
    REQUIRE(file_fixture_open(&a, NULL, 0) && file_fixture_open(&b, NULL, 0), 10);
    FILE *first = fopen(a.path, "w"), *second = fopen(b.path, "w");
    REQUIRE(first && second, 20);
    REQUIRE(fputs("A", first) >= 0 && fputs("B", second) >= 0, 70);
    injection = ONE_STREAM;
    int result = fflush(NULL);
    injection = OFF;
    REQUIRE(result == EOF && injected_error && (!!ferror(first) ^ !!ferror(second)), 71);
    char byte;
    long first_count = file_fixture_read(&a, &byte, 1);
    REQUIRE(first_count == 0 || (first_count == 1 && byte == 'A'), 72);
    long second_count = file_fixture_read(&b, &byte, 1);
    REQUIRE(second_count == 0 || (second_count == 1 && byte == 'B'), 73);
    REQUIRE(first_count + second_count == 1, 74);
    REQUIRE(fclose(first) == 0 && fclose(second) == 0
            && file_fixture_close(&a) && file_fixture_close(&b), 75);
    return 0;
}

int main(int argc, char **argv)
{
    REQUIRE(argc == 2, 9);
    if (same(argv[1], "read-retry"))
        return read_retry();
    if (same(argv[1], "write-retry"))
        return write_retry();
    if (same(argv[1], "recover"))
        return recover();
    if (same(argv[1], "close"))
        return close_failure();
    if (same(argv[1], "close-pipe"))
        return close_pipe();
    if (same(argv[1], "partial-element"))
        return partial_element();
    if (same(argv[1], "flush-all"))
        return flush_all_failure();
    return 11;
}
