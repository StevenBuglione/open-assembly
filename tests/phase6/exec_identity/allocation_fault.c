#include "fixture.h"

#include <stdlib.h>

extern void *__real_malloc(size_t);
extern void __real_free(void *);

enum phase { DISARMED, DENY_ONCE, OBSERVE };
static enum phase active;
static unsigned denied, allocated, released;
static uintptr_t owned[8];

void *__wrap_malloc(size_t size)
{
    if (active == DISARMED)
        return __real_malloc(size);
    if (active == DENY_ONCE && !denied) {
        denied = 1;
        errno = ENOMEM;
        return NULL;
    }
    if (!size || allocated == sizeof owned / sizeof *owned)
        _exit(43);
    void *result = __real_malloc(size);
    if (!result)
        _exit(91);
    owned[allocated++] = (uintptr_t)result;
    return result;
}

void __wrap_free(void *pointer)
{
    if (active != DISARMED && pointer) {
        unsigned index = 0;
        while (index < allocated && owned[index] != (uintptr_t)pointer)
            ++index;
        if (index == allocated)
            _exit(43);
        owned[index] = 0;
        ++released;
    }
    __real_free(pointer);
}

static int check(enum phase phase, char **current, char **args, int expected, int mismatch)
{
    denied = allocated = released = 0;
    char *zero = args[0], *token = args[1], *path = current[0];
    errno = TEST_ERRNO;
    active = phase;
    int result = execvp("fixture-command", args);
    int error = errno;
    active = DISARMED;
    if (environ != current || args[0] != zero || args[1] != token || args[2] ||
        current[0] != path || current[1] || !same_text(zero, "explicit-name") ||
        !same_text(token, "two words") || !same_text(path, "PATH=absent-one:absent-two"))
        return 44;
    if (result != -1 || error != expected || allocated != released ||
        (phase == DENY_ONCE ? denied != 1 : !allocated || denied))
        return mismatch;
    return 0;
}

int main(void)
{
    struct kernel_stat st;
    if (raw_stat(AT_FDCWD, "absent-one", 0, &st) != -ENOENT ||
        raw_stat(AT_FDCWD, "absent-two", 0, &st) != -ENOENT)
        return 90;
    char path[] = "PATH=absent-one:absent-two", zero[] = "explicit-name", token[] = "two words";
    char *current[] = {path, NULL};
    char *args[] = {zero, token, NULL};
    char **original = environ;
    environ = current;
    int result = check(DENY_ONCE, current, args, ENOMEM, 41);
    if (!result)
        result = check(OBSERVE, current, args, ENOENT, 42);
    environ = original;
    return result;
}
