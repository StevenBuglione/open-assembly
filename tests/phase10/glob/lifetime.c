#include "tree.h"

#include <errno.h>
#include <glob.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

extern void *__real_malloc(size_t);
extern void *__real_calloc(size_t, size_t);
extern void *__real_realloc(void *, size_t);
extern void __real_free(void *);

static uintptr_t owned[64];
static unsigned live, attempts, fail_at, failures;
static int active, in_allocator, invalid;

static int lookup(uintptr_t address)
{
    for (unsigned i = 0; i < sizeof owned / sizeof owned[0]; ++i)
        if (owned[i] == address)
            return (int)i;
    return -1;
}

static void add(void *pointer)
{
    if (!pointer)
        return;
    int slot = lookup(0);
    if (slot < 0 || lookup((uintptr_t)pointer) >= 0) {
        invalid = 1;
        return;
    }
    owned[slot] = (uintptr_t)pointer;
    ++live;
}

static int inject(void)
{
    if (++attempts != fail_at)
        return 0;
    ++failures;
    errno = ENOMEM;
    return 1;
}

void *__wrap_malloc(size_t size)
{
    if (!active || in_allocator)
        return __real_malloc(size);
    if (inject())
        return NULL;
    in_allocator = 1;
    void *pointer = __real_malloc(size);
    in_allocator = 0;
    add(pointer);
    return pointer;
}

void *__wrap_calloc(size_t count, size_t size)
{
    if (!active || in_allocator)
        return __real_calloc(count, size);
    if (inject())
        return NULL;
    in_allocator = 1;
    void *pointer = __real_calloc(count, size);
    in_allocator = 0;
    add(pointer);
    return pointer;
}

void *__wrap_realloc(void *pointer, size_t size)
{
    if (!active || in_allocator)
        return __real_realloc(pointer, size);
    int slot = pointer ? lookup((uintptr_t)pointer) : -1;
    if (pointer && slot < 0)
        invalid = 1;
    if (inject())
        return NULL;
    in_allocator = 1;
    void *result = __real_realloc(pointer, size);
    in_allocator = 0;
    if (result) {
        if (slot >= 0)
            owned[slot] = (uintptr_t)result;
        else
            add(result);
    }
    return result;
}

void __wrap_free(void *pointer)
{
    if (!active || in_allocator) {
        __real_free(pointer);
        return;
    }
    if (pointer) {
        int slot = lookup((uintptr_t)pointer);
        if (slot < 0) {
            invalid = 1;
            return;
        }
        owned[slot] = 0;
        --live;
    }
    in_allocator = 1;
    __real_free(pointer);
    in_allocator = 0;
}

static int original(const glob_t *result)
{
    return result->gl_pathc >= 2 && result->gl_pathv && result->gl_pathv[0] && result->gl_pathv[1] &&
           !strcmp(result->gl_pathv[0], "root/B.txt") && !strcmp(result->gl_pathv[1], "root/a.txt") &&
           !result->gl_pathv[result->gl_pathc];
}

static int release(void)
{
    glob_t result = {0};
    active = 1;
    if (glob("root/*.txt", 0, NULL, &result) || !original(&result) || !live)
        return 90;
    errno = EDOM;
    globfree(&result);
    active = 0;
    return result.gl_pathc == 0 && !result.gl_pathv && !live && !invalid && errno == EDOM ? 0 : 31;
}

static int error_calls;
static int unexpected(const char *path, int error)
{
    (void)path;
    (void)error;
    ++error_calls;
    return 1;
}

static int append(unsigned fault, unsigned *baseline)
{
    glob_t result = {0};
    fail_at = 0;
    active = 1;
    if (glob("root/*.txt", 0, NULL, &result) || !original(&result))
        return 90;
    attempts = failures = 0;
    fail_at = fault;
    int status = glob("root/dir/*.txt", GLOB_APPEND, unexpected, &result);
    fail_at = 0;
    if (fault ? status != GLOB_NOSPACE || failures != 1 : status || failures)
        return 32;
    if (error_calls || !original(&result) || result.gl_pathc > 4 || (!fault && result.gl_pathc != 4))
        return 33;
    unsigned seen = 0;
    for (size_t i = 2; i < result.gl_pathc; ++i) {
        const char *name = result.gl_pathv[i];
        unsigned bit = !strcmp(name, "root/dir/c.txt") ? 1u : !strcmp(name, "root/dir/d.txt") ? 2u : 0;
        if (!bit || (seen & bit))
            return 34;
        seen |= bit;
    }
    if (!fault)
        *baseline = attempts;
    globfree(&result);
    active = 0;
    return live || invalid || result.gl_pathc || result.gl_pathv ? 35 : 0;
}

int main(int argc, char **argv)
{
    if (argc != 2 || !basic_tree())
        return 90;
    if (!strcmp(argv[1], "release"))
        return release();
    if (strcmp(argv[1], "allocation-fault"))
        return 91;
    unsigned baseline = 0;
    int status = append(0, &baseline);
    if (status || baseline < 4 || baseline > 64)
        return status ? status : 92;
    for (unsigned fault = 1; fault <= baseline; ++fault)
        if ((status = append(fault, &baseline)))
            return status;
    return 0;
}
