#include "image.h"

#include <sys/mman.h>

extern size_t __al_vdso_lookup(const void *, size_t);
extern long __al_syscall(long, long, long, long, long, long, long);

static int check(unsigned char *storage, const unsigned char *original, size_t size,
                 int right, size_t expected)
{
    unsigned char *image = right ? storage + PAGE_SIZE - size : storage;
    if (__al_syscall(10, (long)storage, PAGE_SIZE, PROT_READ | PROT_WRITE, 0, 0, 0))
        return 0;
    memcpy(image, original, size);
    if (__al_syscall(10, (long)storage, PAGE_SIZE, PROT_READ, 0, 0, 0))
        return 0;
    return __al_vdso_lookup(image, size) == expected;
}

int main(void)
{
    unsigned char *mapping = mmap(NULL, 3 * PAGE_SIZE, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mapping == MAP_FAILED)
        return 90;
    unsigned char *storage = mapping + PAGE_SIZE;
    unsigned char original[PAGE_SIZE], malformed[PAGE_SIZE];
    fixture_image(original, 1);
    const size_t cuts[] = {1, 15, 63, 64, 119, 175, DYNAMIC, STRINGS - 1, HASH,
                           SYMBOLS + 24, VERSIONS, DEFINITION + 20, ENTRY};
    const struct { unsigned offset, width; uint64_t value; } edits[] = {
        {0, 1, 0}, {4, 1, 1}, {5, 1, 2}, {16, 2, 2}, {18, 2, 183},
        {32, 8, UINT64_MAX - 20}, {54, 2, 55}, {56, 2, 0xffff},
        {LOAD_HEADER + 4, 4, 4}, {LOAD_HEADER + 8, 8, 1}, {LOAD_HEADER + 16, 8, 1},
        {LOAD_HEADER + 32, 8, UINT64_MAX}, {DYNAMIC_HEADER + 8, 8, PAGE_SIZE},
        {DYNAMIC_HEADER + 32, 8, UINT64_MAX}, {DYNAMIC, 8, 0x6ffffef5},
        {DYNAMIC + 8, 8, UINT64_MAX}, {DYNAMIC + 16 * 3 + 8, 8, 2},
        {DYNAMIC + 16 * 4 + 8, 8, 16}, {DYNAMIC + 16 * 7 + 8, 8, UINT64_MAX},
        {DYNAMIC + 16 * 8, 8, 1}, {STRINGS + 1, 1, 'x'},
        {STRINGS + sizeof "__vdso_clock_gettime", 1, 'X'},
        {HASH + 4, 4, 0x7fffffffu}, {SYMBOLS + 24, 4, UINT32_MAX},
        {SYMBOLS + 28, 1, 0x1a}, {SYMBOLS + 30, 2, 0},
        {SYMBOLS + 32, 8, 0}, {SYMBOLS + 32, 8, PAGE_SIZE},
        {SYMBOLS + 40, 8, UINT64_MAX}, {VERSIONS + 2, 2, 3},
        {DEFINITION + 12, 4, 0xfffffffeu}, {DEFINITION + 20, 4, UINT32_MAX},
    };

    for (int right = 0; right < 2; ++right) {
        if (!check(storage, original, sizeof original, right, ENTRY))
            return 11;
        for (size_t i = 0; i < sizeof cuts / sizeof cuts[0]; ++i)
            if (!check(storage, original, cuts[i], right, 0))
                return 20 + (int)i;
        for (size_t i = 0; i < sizeof edits / sizeof edits[0]; ++i) {
            memcpy(malformed, original, sizeof malformed);
            word(malformed + edits[i].offset, edits[i].value, edits[i].width);
            if (!check(storage, malformed, sizeof malformed, right, 0))
                return 40 + (int)i;
        }
    }
    return munmap(mapping, 3 * PAGE_SIZE) == 0 ? 0 : 90;
}
