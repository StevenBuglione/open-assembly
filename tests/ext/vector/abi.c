#include <stdint.h>
#include <string.h>
#include <vector.h>

extern unsigned phase2_abi_probe(uintptr_t target, const uint64_t arguments[6]);

int main(int argc, char **argv)
{
    _Alignas(16) unsigned char old[8] = {0x85}, fresh[32];
    size_t state[] = {(uintptr_t)old, 1, 1, 8, 8};
    size_t arena[] = {(uintptr_t)fresh, sizeof fresh, 0};
    unsigned char copied[8];
    void *element;
    if (argc != 2)
        return 90;
    uintptr_t target;
    uint64_t arguments[6] = {(uintptr_t)state};
    if (!strcmp(argv[1], "init")) {
        target = (uintptr_t)vector_init;
        arguments[1] = 8;
        arguments[2] = 8;
    } else if (!strcmp(argv[1], "reserve")) {
        target = (uintptr_t)vector_reserve;
        arguments[1] = (uintptr_t)arena;
        arguments[2] = 2;
    } else if (!strcmp(argv[1], "push")) {
        target = (uintptr_t)vector_push;
        arguments[1] = (uintptr_t)arena;
        arguments[2] = (uintptr_t)old;
    } else if (!strcmp(argv[1], "pop")) {
        target = (uintptr_t)vector_pop;
        arguments[1] = (uintptr_t)copied;
    } else if (!strcmp(argv[1], "at")) {
        target = (uintptr_t)vector_at;
        arguments[2] = (uintptr_t)&element;
    } else {
        return 91;
    }
    return phase2_abi_probe(target, arguments) != 0;
}
