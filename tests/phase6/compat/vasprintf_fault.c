#include "../kernel_abi.h"
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

static int armed;
static unsigned failed, released;
static void *growth_buffer;

void *__real_realloc(void *, size_t);
void __real_free(void *);

void *__wrap_realloc(void *old, size_t size)
{
    if (armed && !failed && old && size >= 1024) {
        growth_buffer = old;
        ++failed;
        errno = ENOMEM;
        return NULL;
    }
    return __real_realloc(old, size);
}

void __wrap_free(void *pointer)
{
    if (armed && failed && pointer == growth_buffer)
        ++released;
    __real_free(pointer);
}

static int render(char **output, const char *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    int result = vasprintf(output, format, arguments);
    va_end(arguments);
    return result;
}

int main(void)
{
    char sentinel = 'X';
    char *output = &sentinel;
    int before = -1, after = -1;
    armed = 1;
    errno = TEST_ERRNO;
    int result = render(&output, "start%n%4096s%n", &before, "x", &after);
    armed = 0;
    if (failed != 1 || released != 1)
        return 30;
    if (result >= 0 || output || errno != ENOMEM || before != 5 || after != -1 || sentinel != 'X')
        return 31;
    return 0;
}
