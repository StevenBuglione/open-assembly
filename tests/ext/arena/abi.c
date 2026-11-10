#include <arena.h>
#include <stdint.h>
#include <string.h>

extern unsigned phase2_abi_probe(uintptr_t target, const uint64_t arguments[6]);

int main(int argc, char **argv)
{
    size_t state[] = {16, 96, 11};
    void *result;
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "init"))
        return phase2_abi_probe((uintptr_t)arena_init, (uint64_t[6]){(uintptr_t)state, 16, 96}) != 0;
    if (!strcmp(argv[1], "alloc"))
        return phase2_abi_probe((uintptr_t)arena_alloc,
                                (uint64_t[6]){(uintptr_t)state, 7, 8, (uintptr_t)&result}) != 0;
    if (!strcmp(argv[1], "reset"))
        return phase2_abi_probe((uintptr_t)arena_reset, (uint64_t[6]){(uintptr_t)state}) != 0;
    return 91;
}
