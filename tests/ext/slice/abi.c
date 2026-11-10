#include <slice.h>
#include <stdint.h>
#include <string.h>

extern unsigned phase2_abi_probe(uintptr_t target, const uint64_t arguments[6]);

int main(int argc, char **argv)
{
    const unsigned char bytes[] = {0x80, 0xff, 0, 0xff};
    const unsigned char *cursor = bytes, *result;
    size_t available = sizeof bytes, offset = 7;
    unsigned value;
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "take"))
        return phase2_abi_probe((uintptr_t)slice_take, (uint64_t[6]){
            (uintptr_t)&cursor, (uintptr_t)&available, 3, (uintptr_t)&result}) != 0;
    if (!strcmp(argv[1], "find"))
        return phase2_abi_probe((uintptr_t)slice_find_byte, (uint64_t[6]){
            (uintptr_t)bytes, sizeof bytes, UINT64_C(0x9aeefab1000000ff), (uintptr_t)&offset}) != 0 || offset != 1;
    if (!strcmp(argv[1], "load"))
        return phase2_abi_probe((uintptr_t)slice_load_u32be, (uint64_t[6]){
            (uintptr_t)bytes, sizeof bytes, (uintptr_t)&value}) != 0;
    return 91;
}
