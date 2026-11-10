#include <map.h>
#include <stdint.h>
#include <string.h>

extern unsigned phase2_abi_probe(uintptr_t target, const uint64_t arguments[6]);

int main(int argc, char **argv)
{
    size_t slots[16] = {0}, state[] = {(uintptr_t)slots, 4, 0, 0};
    unsigned char storage[16];
    size_t arena[] = {(uintptr_t)storage, sizeof storage, 0};
    const unsigned char key[] = {0, 0x80, 0xff};
    size_t value;
    if (argc != 2)
        return 90;
    uintptr_t target;
    uint64_t args[6] = {(uintptr_t)state, (uintptr_t)key, sizeof key, (uintptr_t)&value};
    if (!strcmp(argv[1], "init")) {
        target = (uintptr_t)map_init;
        args[1] = (uintptr_t)slots;
        args[2] = 4;
        args[3] = 9;
    } else if (!strcmp(argv[1], "probe")) {
        target = (uintptr_t)map_probe;
    } else if (!strcmp(argv[1], "get")) {
        target = (uintptr_t)map_get;
    } else if (!strcmp(argv[1], "put")) {
        target = (uintptr_t)map_put;
        args[1] = (uintptr_t)arena;
        args[2] = (uintptr_t)key;
        args[3] = sizeof key;
        args[4] = UINT64_C(0xace3fc99554437fe);
    } else if (!strcmp(argv[1], "remove")) {
        target = (uintptr_t)map_remove;
    } else {
        return 91;
    }
    return phase2_abi_probe(target, args) != 0;
}
