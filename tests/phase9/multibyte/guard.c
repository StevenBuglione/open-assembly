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
    char32_t scalar = 0xfeed;
    mbstate_t state = {0};
    errno = EDOM;
    if (mbrtoc32(&scalar, right, 0, &state) != (size_t)-2 || scalar != 0xfeed || !mbsinit(&state))
        return 73;
    right[-1] = (char)0xf0;
    if (mbrtoc32(&scalar, right - 1, 1, &state) != (size_t)-2 || scalar != 0xfeed || mbsinit(&state) ||
        mbrtoc32(&scalar, right, 0, &state) != (size_t)-2 || scalar != 0xfeed)
        return 74;
    memcpy(left, "\x90\x80\x80", 3);
    if (mbrtoc32(&scalar, left, 3, &state) != 3 || scalar != 0x10000 || !mbsinit(&state))
        return 75;
    memcpy(right - 4, "\xf4\x8f\xbf\xbf", 4);
    char16_t unit = 0;
    if (mbrtoc16(&unit, right - 4, 4, &state) != 4 || unit != 0xdbff ||
        mbrtoc16(&unit, right, 0, &state) != (size_t)-3 || unit != 0xdfff || !mbsinit(&state))
        return 76;
    if (c32rtomb(right - 4, 0x10000, &state) != 4 || memcmp(right - 4, "\xf0\x90\x80\x80", 4))
        return 77;
    if (c16rtomb(right, 0xd83d, &state) || mbsinit(&state) ||
        c16rtomb(right - 4, 0xde42, &state) != 4 || memcmp(right - 4, "\xf0\x9f\x99\x82", 4) ||
        !mbsinit(&state) || errno != EDOM)
        return 78;
    return __al_syscall(MUNMAP, start, 3 * page, 0, 0, 0, 0) ? 79 : 0;
}
