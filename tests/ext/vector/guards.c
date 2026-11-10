#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <vector.h>

extern long __al_syscall(long, long, long, long, long, long, long);
struct aux_entry { unsigned long key, value; };
extern const struct aux_entry *const __al_auxv;

int main(void)
{
    size_t page = 0;
    for (const struct aux_entry *entry = __al_auxv; entry->key; ++entry)
        if (entry->key == 6)
            page = entry->value;
    if (!page)
        return 90;
    long mapping = __al_syscall(9, 0, (long)(7 * page), 0, 0x22, -1, 0);
    if (mapping < 0)
        return 91;
    for (long index = 1; index <= 5; index += 2)
        if (__al_syscall(10, mapping + index * (long)page, (long)page, 3, 0, 0, 0))
            return 92;

    const unsigned char input[8] = {0xff, 0, 0x80, 0x7f, 0, 0x91, 2, 7};
    for (size_t side = 0; side < 2; ++side) {
        unsigned char *old = (unsigned char *)(mapping + (long)page) + side * (page - 8);
        unsigned char *fresh = (unsigned char *)(mapping + (long)(3 * page)) + side * (page - 16);
        unsigned char *out = (unsigned char *)(mapping + (long)(5 * page)) + side * (page - 8);
        if (__al_syscall(10, mapping + (long)page, (long)page, 3, 0, 0, 0))
            return 93;
        memcpy(old, input, sizeof input);
        if (__al_syscall(10, mapping + (long)page, (long)page, 1, 0, 0, 0))
            return 94;
        size_t state[] = {(uintptr_t)old, 1, 1, 8, 8};
        size_t arena[] = {(uintptr_t)fresh, 16, 0};
        errno = EDOM;
        if (vector_push(state, arena, old) || state[0] != (uintptr_t)fresh || state[1] != 2 ||
            state[2] != 2 || arena[2] != 16 || memcmp(fresh, input, 8) ||
            memcmp(fresh + 8, input, 8) || errno != EDOM)
            return 11;
        if (vector_at(state, 1, (void **)out) || *(void **)out != fresh + 8 || errno != EDOM)
            return 12;
        if (vector_pop(state, out) || state[1] != 1 || memcmp(out, input, 8) || errno != EDOM)
            return 13;
        if (vector_pop(state, NULL) || state[1] || errno != EDOM ||
            vector_pop(state, out) != -ENOENT || memcmp(out, input, 8))
            return 14;
    }
    return __al_syscall(11, mapping, (long)(7 * page), 0, 0, 0, 0) ? 95 : 0;
}
