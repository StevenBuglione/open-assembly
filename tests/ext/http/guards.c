#include <errno.h>
#include <http.h>
#include <stdint.h>
#include <string.h>

extern long __al_syscall(long, long, long, long, long, long, long);

int main(void)
{
    enum { PAGE = 4096, LIMIT = 8192 };
    long address = __al_syscall(9, 0, PAGE * 4, 0, 0x22, -1, 0);
    if (address <= 0)
        return 90;
    unsigned char *map = (void *)(uintptr_t)address, *span = map + PAGE;
    if (__al_syscall(10, (long)span, LIMIT, 3, 0, 0, 0))
        return 91;
    static const char prefix[] = "HEAD /missing HTTP/1.0\r\nPad:";
    memset(span, 'x', LIMIT);
    memcpy(span, prefix, sizeof prefix - 1);
    memcpy(span + LIMIT - 4, "\r\n\r\n", 4);
    if (__al_syscall(10, (long)span, LIMIT, 1, 0, 0, 0))
        return 92;
    errno = EDOM;
    if (http_find_header_end(span, LIMIT) != LIMIT || http_find_header_end(span + LIMIT - 4, 4) != 4 ||
        http_find_header_end(span + LIMIT - 3, 3) || http_find_header_end(span + LIMIT, 0) ||
        http_find_header_end(span, LIMIT - 1))
        return 11;
    if (http_parse(span, LIMIT) != ((1u << 16) | 404) || http_parse(span, LIMIT - 1) ||
        http_parse(span + LIMIT - 4, 4) != 400 || http_parse(span + LIMIT, 0) || errno != EDOM)
        return 12;
    return __al_syscall(11, address, PAGE * 4, 0, 0, 0, 0) ? 93 : 0;
}
