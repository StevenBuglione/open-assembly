#include <errno.h>
#include <stdint.h>
#include <stdlib.h>

static unsigned char value(size_t i)
{
    return (unsigned char)(i * 33u + (i >> 11) + 101u);
}

int main(void)
{
    const size_t small = 524299, large = 1048613;
    unsigned char *allocation = malloc(small);
    if (!allocation)
        return 90;
    for (size_t i = 0; i < small; ++i)
        allocation[i] = value(i);
    errno = EDOM;
    unsigned char *grown = realloc(allocation, large);
    if (!grown || (uintptr_t)grown % 16 || errno != EDOM)
        return 11;
    for (size_t i = 0; i < small; ++i)
        if (grown[i] != value(i))
            return 12;
    grown[large - 1] = 0x35;
    errno = EDOM;
    volatile size_t oversized = (size_t)PTRDIFF_MAX + 1;
    if (realloc(grown, oversized) || errno != ENOMEM || grown[large - 1] != 0x35)
        return 13;
    for (size_t i = 0; i < small; ++i)
        if (grown[i] != value(i))
            return 14;
    free(grown);
    return 0;
}
