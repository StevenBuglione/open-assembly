#include "../kernel_abi.h"

#include <stdint.h>
#include <stdlib.h>

extern void *__real_malloc(size_t);
extern void __real_free(void *);
extern long __real___al_syscall(long, long, long, long, long, long, long);

enum arm {
    OFF, DENIED, SHORT, UNREACHABLE, CALLER, ZERO, DEFAULT, EXPLICIT, MAX_ERROR,
};

static enum arm active;
static uintptr_t allocation, caller;
static size_t allocation_size, capacity;
static unsigned allocated, freed, requests;
static const char unreachable[] = "(unreachable)/fixture";
static char expected[4096];
static char buffer[4098];

static int owned(void)
{
    return active == DENIED || active == SHORT || active == DEFAULT || active == EXPLICIT;
}

void *__wrap_malloc(size_t size)
{
    if (active == OFF)
        return __real_malloc(size);
    if (!owned() || ++allocated != 1 ||
        (active == DEFAULT ? size < sizeof expected : size != capacity))
        _exit(27);
    if (active == DENIED) {
        errno = ENOMEM;
        return NULL;
    }
    void *result = __real_malloc(size);
    if (!result)
        _exit(91);
    allocation = (uintptr_t)result;
    allocation_size = size;
    return result;
}

void __wrap_free(void *pointer)
{
    if (active != OFF && pointer) {
        if ((uintptr_t)pointer != allocation || !allocation || ++freed != 1)
            _exit(27);
    }
    __real_free(pointer);
}

long __wrap___al_syscall(long nr, long a1, long a2, long a3, long a4, long a5, long a6)
{
    if (active == OFF || nr != __NR_getcwd)
        return __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
    if (++requests != 1 || active == DENIED || active == ZERO)
        _exit(27);
    if (owned()) {
        if ((uintptr_t)a1 != allocation || !allocation || freed ||
            (active == DEFAULT ? (a2 < (long)sizeof expected || (size_t)a2 > allocation_size)
                               : (size_t)a2 != capacity))
            _exit(27);
    } else if ((uintptr_t)a1 != caller || (size_t)a2 != capacity) {
        _exit(27);
    }
    if (active == MAX_ERROR)
        return -4095;
    if (active == UNREACHABLE) {
        if ((size_t)a2 < sizeof unreachable)
            _exit(92);
        char *bytes = (char *)(uintptr_t)a1;
        for (size_t i = 0; i < sizeof unreachable; ++i)
            bytes[i] = unreachable[i];
        return sizeof unreachable;
    }
    return __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
}

static int exercise(enum arm which, size_t size, size_t length, int want_errno, int status)
{
    caller = (uintptr_t)(buffer + 1);
    allocation = 0;
    capacity = size;
    allocated = freed = requests = 0;
    for (size_t i = 0; i < sizeof buffer; ++i)
        buffer[i] = '!';
    errno = TEST_ERRNO;
    active = which;
    int expect_owned = owned();
    char *result = getcwd(expect_owned ? NULL : buffer + 1, size);
    int error = errno;
    active = OFF;

    int success = want_errno == TEST_ERRNO;
    if (error != want_errno || !!result != success || allocated != (unsigned)expect_owned ||
        freed != (unsigned)(which == SHORT) ||
        requests != (unsigned)(which != DENIED && which != ZERO))
        return status;
    if (result && ((uintptr_t)result != (expect_owned ? allocation : caller) ||
                   result[length - 1] || !same_text(result, expected)))
        return status;
    if (result && expect_owned)
        free(result);
    if (buffer[0] != '!' || buffer[sizeof buffer - 1] != '!')
        return status;
    if (which == MAX_ERROR || which == ZERO) {
        for (size_t i = 1; i < sizeof buffer - 1; ++i)
            if (buffer[i] != '!')
                return status;
    }
    return 0;
}

int main(void)
{
    long length = __real___al_syscall(__NR_getcwd, (long)expected, sizeof expected, 0, 0, 0, 0);
    if (length < 2 || length > (long)sizeof expected || expected[0] != '/' || expected[length - 1])
        return 90;
    static const struct {
        enum arm which;
        int error, status;
    } cases[] = {
        {DENIED, ENOMEM, 21}, {SHORT, ERANGE, 22}, {UNREACHABLE, ENOENT, 23},
        {CALLER, TEST_ERRNO, 24}, {ZERO, EINVAL, 24}, {DEFAULT, TEST_ERRNO, 25},
        {EXPLICIT, TEST_ERRNO, 26}, {MAX_ERROR, 4095, 28},
    };
    for (size_t i = 0; i < sizeof cases / sizeof *cases; ++i) {
        enum arm which = cases[i].which;
        size_t size = (size_t)length;
        if (which == ZERO || which == DEFAULT)
            size = 0;
        else if (which == SHORT)
            size = 1;
        else if (which == UNREACHABLE)
            size = sizeof buffer - 2;
        int result = exercise(which, size, (size_t)length, cases[i].error, cases[i].status);
        if (result)
            return result;
    }
    return 0;
}
