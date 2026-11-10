#include <errno.h>
#include <map.h>
#include <stdint.h>

extern long __al_syscall(long, long, long, long, long, long, long);

static int edge(size_t *slots, const unsigned char *key)
{
    size_t state[4] = {0};
    unsigned char bytes[3];
    size_t arena[] = {(uintptr_t)bytes, sizeof bytes, 0};
    size_t value = 0;
    const unsigned char different[] = {0, 0x80, 0xfe};
    errno = EDOM;
    if (map_init(state, slots, 1, UINT64_C(0x8000000045673219)) ||
        map_put(state, arena, key, 3, 29) || state[2] != 1 || arena[2] != 3 ||
        bytes[0] != 0 || bytes[1] != 0x80 || bytes[2] != 0xff)
        return 11;
    if (map_probe(state, key, 3) != 1 || map_get(state, key, 3, &value) || value != 29 ||
        map_probe(state, different, 3) != -ENOSPC ||
        map_get(state, different, 3, &value) != -ENOENT || value != 29)
        return 12;
    if (map_remove(state, key, 3, &value) || value != 29 || state[2] || arena[2] != 3 ||
        map_put(state, NULL, NULL, 0, 37) || state[2] != 1 || arena[2] != 3 ||
        map_get(state, key, 0, &value) || value != 37 || errno != EDOM)
        return 13;
    return 0;
}

int main(void)
{
    enum { PAGE = 4096 };
    long address = __al_syscall(9, 0, PAGE * 5, 0, 0x22, -1, 0);
    if (address <= 0)
        return 90;
    unsigned char *mapping = (void *)(uintptr_t)address;
    unsigned char *slots = mapping + PAGE, *keys = mapping + PAGE * 3;
    if (__al_syscall(10, (long)slots, PAGE, 3, 0, 0, 0) ||
        __al_syscall(10, (long)keys, PAGE, 3, 0, 0, 0))
        return 91;
    keys[0] = keys[PAGE - 3] = 0;
    keys[1] = keys[PAGE - 2] = 0x80;
    keys[2] = keys[PAGE - 1] = 0xff;
    if (__al_syscall(10, (long)keys, PAGE, 1, 0, 0, 0))
        return 92;
    int status = edge((size_t *)slots, keys);
    if (!status)
        status = edge((size_t *)(slots + PAGE - 4 * sizeof(size_t)), keys + PAGE - 3);
    return __al_syscall(11, address, PAGE * 5, 0, 0, 0, 0) ? 93 : status;
}
