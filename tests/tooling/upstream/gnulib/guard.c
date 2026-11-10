#define _GNU_SOURCE 1
#include <stdlib.h>
#include <sys/mman.h>

extern void *__real_mmap(void *, size_t, int, int, int, off_t);
extern int __real_mprotect(void *, size_t, int);

/* The upstream probe can omit guard vectors on unavailable mappings.
   Require those mappings in this Linux scope and preserve the real result. */
void *__wrap_mmap(void *address, size_t length, int prot, int flags, int fd, off_t offset)
{
    void *mapping = __real_mmap(address, length, prot, flags, fd, offset);
    if (mapping == MAP_FAILED)
        _Exit(125);
    return mapping;
}

int __wrap_mprotect(void *address, size_t length, int protection)
{
    int result = __real_mprotect(address, length, protection);
    if (result)
        _Exit(125);
    return result;
}
