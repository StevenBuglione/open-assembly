#include <unistd.h>

volatile int t_status;

/* Upstream assertions call t_printf on failure. Use the Phase 1 byte
 * writer so a broken formatting candidate cannot hide that failure. */
int t_printf(const char *format, ...)
{
    size_t length = 0;
    while (format[length])
        ++length;
    t_status = 1;
    return (int)write(STDERR_FILENO, format, length);
}
