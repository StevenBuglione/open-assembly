#include <errno.h>
#include <slice.h>
#include <stdint.h>
#include <string.h>

#define MAX UINT64_MAX

static const unsigned char bytes[] = {0x11, 0x80, 0xff, 0, 0xff, 0x7a, 0x42};

static int take(void)
{
    const struct {
        uintptr_t base;
        size_t available, length, missing;
        int expected;
    } rows[] = {
        {(uintptr_t)bytes, 7, 3, 0, 0}, {(uintptr_t)bytes, 7, 7, 0, 0},
        {(uintptr_t)bytes, 7, 0, 0, 0}, {0, 0, 0, 0, 0},
        {0, 1, 0, 0, -EINVAL}, {0, 0, 1, 0, -ERANGE},
        {(uintptr_t)bytes, 7, 8, 0, -ERANGE}, {MAX - 4, 5, 0, 0, -EOVERFLOW},
        {MAX - 4, 4, 4, 0, 0}, {MAX, 0, 0, 0, 0},
        {(uintptr_t)bytes, 7, 1, 1, -EINVAL}, {(uintptr_t)bytes, 7, 1, 2, -EINVAL},
        {(uintptr_t)bytes, 7, 1, 3, -EINVAL},
    };
    for (size_t i = 0; i < sizeof rows / sizeof rows[0]; ++i) {
        const unsigned char *cursor = (const unsigned char *)rows[i].base;
        const unsigned char *result = bytes + 6;
        size_t available = rows[i].available;
        errno = EDOM;
        int status = slice_take(rows[i].missing == 1 ? NULL : &cursor,
                                rows[i].missing == 2 ? NULL : &available, rows[i].length,
                                rows[i].missing == 3 ? NULL : &result);
        size_t consumed = rows[i].expected ? 0 : rows[i].length;
        uintptr_t expected = rows[i].expected ? (uintptr_t)(bytes + 6) : rows[i].base;
        if (status != rows[i].expected || errno != EDOM || (uintptr_t)result != expected ||
            (uintptr_t)cursor != rows[i].base + consumed || available != rows[i].available - consumed)
            return 11 + (int)i;
    }
    return 0;
}

static int find(void)
{
    const struct {
        uintptr_t base;
        size_t length;
        unsigned needle;
        int missing, status;
        size_t offset;
    } rows[] = {
        {(uintptr_t)bytes, 7, 0xff, 0, 0, 2}, {(uintptr_t)bytes, 7, 0x11, 0, 0, 0},
        {(uintptr_t)bytes, 7, 0x42, 0, 0, 6}, {(uintptr_t)bytes, 7, 0, 0, 0, 3},
        {(uintptr_t)bytes, 7, 0x80, 0, 0, 1},
        {(uintptr_t)bytes, 3, 0, 0, -ENOENT, 0}, {(uintptr_t)bytes, 7, 3, 0, -ENOENT, 0},
        {(uintptr_t)bytes, 0, 0x11, 0, -ENOENT, 0}, {0, 0, 0, 0, -ENOENT, 0},
        {0, 1, 0, 0, -EINVAL, 0}, {MAX - 1, 2, 0, 0, -EOVERFLOW, 0},
        {MAX, 0, 0, 0, -ENOENT, 0}, {(uintptr_t)bytes, 7, 0x100, 0, -EINVAL, 0},
        {(uintptr_t)bytes, 7, UINT32_MAX, 0, -EINVAL, 0},
        {(uintptr_t)bytes, 7, 0x11, 1, -EINVAL, 0},
    };
    for (size_t i = 0; i < sizeof rows / sizeof rows[0]; ++i) {
        size_t offset = MAX;
        errno = EDOM;
        int status = slice_find_byte((const unsigned char *)rows[i].base, rows[i].length,
                                     rows[i].needle, rows[i].missing ? NULL : &offset);
        if (status != rows[i].status || offset != (rows[i].status ? MAX : rows[i].offset) ||
            errno != EDOM)
            return 11 + (int)i;
    }
    return 0;
}

static int load(void)
{
    const struct {
        uintptr_t base;
        size_t length;
        int missing, status;
        uint32_t value;
    } rows[] = {
        {(uintptr_t)(bytes + 1), 4, 0, 0, UINT32_C(0x80ff00ff)},
        {(uintptr_t)bytes, 7, 0, 0, UINT32_C(0x1180ff00)},
        {(uintptr_t)(bytes + 1), 3, 0, -ERANGE, 0},
        {0, 0, 0, -ERANGE, 0}, {0, 4, 0, -EINVAL, 0},
        {MAX - 3, 4, 0, -EOVERFLOW, 0}, {(uintptr_t)bytes, 4, 1, -EINVAL, 0},
    };
    for (size_t i = 0; i < sizeof rows / sizeof rows[0]; ++i) {
        unsigned result = UINT32_C(0xa55a8347);
        errno = EDOM;
        int status = slice_load_u32be((const unsigned char *)rows[i].base, rows[i].length,
                                      rows[i].missing ? NULL : &result);
        if (status != rows[i].status || result != (rows[i].status ? UINT32_C(0xa55a8347) : rows[i].value) ||
            errno != EDOM)
            return 11 + (int)i;
    }
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "take"))
        return take();
    if (!strcmp(argv[1], "find"))
        return find();
    if (!strcmp(argv[1], "load"))
        return load();
    return 91;
}
