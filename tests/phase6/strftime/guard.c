#include <errno.h>
#include <time.h>

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
    struct tm date = {.tm_year = 120, .tm_mon = 1, .tm_mday = 9, .tm_isdst = 0};
    static const char wanted[] = "2020-02-09";
    errno = EDOM;
    if (strftime(right, 0, "%F", &date))
        return 72;
    if (strftime(right - sizeof wanted, sizeof wanted, "%F", &date) != sizeof wanted - 1)
        return 73;
    for (size_t i = 0; i < sizeof wanted; ++i) {
        if ((right - sizeof wanted)[i] != wanted[i])
            return 74;
    }
    if (strftime(right - sizeof wanted + 1, sizeof wanted - 1, "%F", &date))
        return 75;
    if (strftime(left, 2, "%%", &date) != 1 || left[0] != '%' || left[1] != '\0')
        return 76;
    right[-4] = 'E';
    right[-3] = 'D';
    right[-2] = 'T';
    right[-1] = '\0';
    date.tm_zone = right - 4;
    if (strftime(left, 4, "%Z", &date) != 3 || left[0] != 'E' || left[1] != 'D' ||
        left[2] != 'T' || left[3] != '\0' || errno != EDOM)
        return 77;
    return __al_syscall(MUNMAP, start, 3 * page, 0, 0, 0, 0) ? 78 : 0;
}
