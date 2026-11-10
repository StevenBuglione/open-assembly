#ifndef OA_LTP_SUBSET_H
#define OA_LTP_SUBSET_H

/* Test-only adapter for the named LTP syscall fixtures. Their source and
   checks remain in the pinned upstream files. The runner supplies cwd. */
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

enum { TPASS = 1, TFAIL, TTERRNO = 0x100, SAFE_WRITE_ALL = 1 };
#define ARRAY_SIZE(array) (sizeof(array) / sizeof((array)[0]))

struct tst_test {
    void (*test_all)(void);
    void (*test)(unsigned int);
    void (*setup)(void);
    void (*cleanup)(void);
    unsigned int tcnt;
    unsigned int needs_tmpdir;
};

static struct tst_test test;
static long TST_RET;
static int TST_ERR;
static unsigned int passes, failures;

static void tst_res(int kind, const char *format, ...) __attribute__((format(printf, 2, 3)));
static void tst_res(int kind, const char *format, ...)
{
    if ((kind & ~TTERRNO) == TPASS) {
        ++passes;
        return;
    }
    ++failures;
    fputs("TFAIL ", stderr);
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    if (kind & TTERRNO)
        fprintf(stderr, " (errno=%d)", TST_ERR);
    fputc('\n', stderr);
}

static _Noreturn void setup_failure(const char *operation)
{
    fprintf(stderr, "TBROK %s (errno=%d)\n", operation, errno);
    exit(2);
}

#define TEST(expression) do { errno = 0; TST_RET = (expression); TST_ERR = errno; } while (0)
#define TST_EXP_FD(expression) do { \
    TEST(expression); \
    tst_res(TST_RET >= 0 ? TPASS : TFAIL | TTERRNO, "%s returned %ld", #expression, TST_RET); \
} while (0)
#define TST_EXP_FAIL2(expression, expected, ...) do { \
    TEST(expression); \
    tst_res(TST_RET == -1 && TST_ERR == (expected) ? TPASS : TFAIL | TTERRNO, __VA_ARGS__); \
} while (0)
#define TST_EXP_EQ_LU(left, right) do { \
    const unsigned long oa_left = (left), oa_right = (right); \
    tst_res(oa_left == oa_right ? TPASS : TFAIL, "%s=%lu %s=%lu", #left, oa_left, #right, oa_right); \
} while (0)
#define SAFE_CLOSE(fd) do { if (close((int)(fd))) setup_failure("close"); (fd) = -1; } while (0)

static inline int SAFE_OPEN(const char *name, int flags, mode_t mode)
{
    int fd = open(name, flags, mode);
    if (fd < 0)
        setup_failure("open");
    return fd;
}

static inline void SAFE_FSTAT(int fd, struct stat *result)
{
    if (fstat(fd, result))
        setup_failure("fstat");
}

static inline void SAFE_READ(int exact, int fd, void *buffer, size_t size)
{
    ssize_t result = read(fd, buffer, size);
    if (result < 0 || (exact && (size_t)result != size))
        setup_failure("read");
}

static inline void SAFE_WRITE(int exact, int fd, const void *buffer, size_t size)
{
    ssize_t result = write(fd, buffer, size);
    if (result < 0 || (exact && (size_t)result != size))
        setup_failure("write");
}

int main(void)
{
    if ((!test.test_all && !test.test) || (test.test_all && test.test) || (test.test && !test.tcnt))
        setup_failure("test registration");
    if (test.setup)
        test.setup();
    if (test.test_all)
        test.test_all();
    else
        for (unsigned int i = 0; i < test.tcnt; ++i)
            test.test(i);
    if (test.cleanup)
        test.cleanup();
    printf("LTP scoped pass=%u fail=%u tmpdir=%u\n", passes, failures, test.needs_tmpdir);
    return failures || !passes ? 1 : 0;
}

#endif
