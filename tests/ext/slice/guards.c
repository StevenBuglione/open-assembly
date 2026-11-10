#include <errno.h>
#include <slice.h>
#include <stdint.h>
#include <string.h>

extern long __al_syscall(long, long, long, long, long, long, long);
struct aux_entry { unsigned long key, value; };
extern const struct aux_entry *const __al_auxv;

int main(void)
{
    size_t page = 0;
    for (const struct aux_entry *item = __al_auxv; item->key; ++item)
        if (item->key == 6)
            page = item->value;
    if (!page)
        return 90;
    long map = __al_syscall(9, 0, (long)(3 * page), 0, 0x22, -1, 0);
    if (map < 0 || __al_syscall(10, map + (long)page, (long)page, 3, 0, 0, 0))
        return 91;
    unsigned char *region = (unsigned char *)(map + (long)page);
    const unsigned char sample[] = {0xff, 0x80, 0, 0x7f};
    unsigned char *edges[] = {region, region + page - sizeof sample};
    for (size_t side = 0; side < 2; ++side)
        memcpy(edges[side], sample, sizeof sample);
    if (__al_syscall(10, (long)region, (long)page, 1, 0, 0, 0))
        return 92;
    for (size_t side = 0; side < 2; ++side) {
        size_t offset = 19;
        unsigned word = 7;
        errno = EDOM;
        if (slice_find_byte(edges[side], sizeof sample, 0x7f, &offset) || offset != 3 ||
            slice_find_byte(edges[side], sizeof sample, 0x44, &offset) != -ENOENT || offset != 3 ||
            errno != EDOM)
            return 11;
        if (slice_load_u32be(edges[side], sizeof sample, &word) || word != UINT32_C(0xff80007f) ||
            slice_load_u32be(region + page - 3, 3, &word) != -ERANGE ||
            word != UINT32_C(0xff80007f) || errno != EDOM)
            return 12;
        const unsigned char *blocked = region + page, *cursor = blocked, *old = edges[side];
        size_t available = page;
        if (slice_take(&cursor, &available, page, &old) || old != blocked ||
            cursor != blocked + page || available || errno != EDOM)
            return 13;
        if (slice_find_byte(blocked, 0, 0xff, &offset) != -ENOENT || offset != 3)
            return 14;
    }
    return __al_syscall(11, map, (long)(3 * page), 0, 0, 0, 0) ? 93 : 0;
}
