/* Oracle diff:glibc. The C17 errno lvalue has thread storage duration.
 * Check the common value and address semantics without assuming glibc's TCB layout. */
#include <errno.h>
#include <limits.h>
#include <stddef.h>

#ifndef __GLIBC__
#error "This oracle must link against glibc"
#endif

static int *(*volatile locate)(void) = __errno_location;

int main(void)
{
    static const int values[] = {0, 1, -50503, 0x12345678, INT_MIN, INT_MAX};
    int *first = locate();
    if (!first)
        return 20;
    for (size_t i = 0; i < sizeof values / sizeof values[0]; ++i) {
        errno = values[i];
        int *cell = locate();
        if (cell != first || *cell != values[i])
            return 21;
        int replacement = values[sizeof values / sizeof values[0] - 1 - i];
        *cell = replacement;
        if (errno != replacement || locate() != first || *first != replacement)
            return 22;
    }
    return 0;
}
