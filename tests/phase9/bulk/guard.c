#include <errno.h>
#include <locale.h>
#include <string.h>
#include <uchar.h>
#include <wchar.h>
#include <stdint.h>

_Static_assert(WCHAR_MIN == INT32_MIN && WCHAR_MAX == INT32_MAX, "wchar/stdint header order");

struct aux_entry { unsigned long type, value; };
extern const struct aux_entry *const __al_auxv;
extern long __al_syscall(long, long, long, long, long, long, long);

enum { AT_PAGESZ = 6, MMAP = 9, MPROTECT = 10, MUNMAP = 11,
       PROT_NONE = 0, PROT_RW = 3, PRIVATE_ANONYMOUS = 0x22 };

static long page_size(void)
{
    for (const struct aux_entry *entry = __al_auxv; entry->type; ++entry) {
        if (entry->type == AT_PAGESZ)
            return (long)entry->value;
    }
    return 0;
}

int main(void)
{
    long page = page_size();
    if (page < 1024)
        return 70;
    long start = __al_syscall(MMAP, 0, 3 * page, PROT_NONE, PRIVATE_ANONYMOUS, -1, 0);
    if (start < 0 || __al_syscall(MPROTECT, start + page, page, PROT_RW, 0, 0, 0))
        return 71;
    char *left = (char *)(start + page), *right = left + page;
    if (!setlocale(LC_CTYPE, "C.UTF-8"))
        return 72;
    mbstate_t state = {0};
    wchar_t *wide = (wchar_t *)left;
    wide[0] = 9;
    wide[1] = 9;
    const char *bytes = right;
    errno = EDOM;
    if (mbsrtowcs(wide, &bytes, 0, &state) || bytes != right || wide[0] != 9)
        return 73;
    memcpy(right - 4, "\xe2\x82\xac", 4);
    bytes = right - 4;
    if (mbsrtowcs(wide, &bytes, 2, &state) != 1 || bytes || wide[0] != 0x20ac || wide[1])
        return 74;
    const wchar_t *input = wide;
    if (wcsrtombs(right, &input, 0, &state) || input != wide)
        return 75;
    if (wcsrtombs(right - 3, &input, 3, &state) != 3 || input != wide + 1 ||
        memcmp(right - 3, "\xe2\x82\xac", 3))
        return 76;
    if (wcsrtombs(right - 1, &input, 1, &state) || input || right[-1] || errno != EDOM)
        return 77;
    return __al_syscall(MUNMAP, start, 3 * page, 0, 0, 0, 0) ? 78 : 0;
}
