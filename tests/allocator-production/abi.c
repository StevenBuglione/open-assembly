#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

extern unsigned phase2_abi_probe_result(uintptr_t function, const uint64_t arguments[6],
                                        uint64_t result[2]);

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    uint64_t arguments[6] = {17, 7};
    uintptr_t target;
    int allocation = 1, output = 0;
    size_t alignment = 16;
    void *out = &out;
    if (!strcmp(argv[1], "malloc")) {
        target = (uintptr_t)malloc;
    } else if (!strcmp(argv[1], "calloc")) {
        target = (uintptr_t)calloc;
    } else if (!strcmp(argv[1], "free")) {
        target = (uintptr_t)free;
        void *pointer = malloc(37);
        if (!pointer)
            return 91;
        arguments[0] = (uintptr_t)pointer;
        allocation = 0;
    } else if (!strcmp(argv[1], "realloc")) {
        target = (uintptr_t)realloc;
        void *pointer = malloc(37);
        if (!pointer)
            return 91;
        arguments[0] = (uintptr_t)pointer;
        arguments[1] = 197;
    } else if (!strcmp(argv[1], "aligned_alloc")) {
        target = (uintptr_t)aligned_alloc;
        arguments[0] = alignment = 64;
        arguments[1] = 73;
    } else if (!strcmp(argv[1], "posix_memalign")) {
        target = (uintptr_t)posix_memalign;
        arguments[0] = (uintptr_t)&out;
        arguments[1] = alignment = 64;
        arguments[2] = 73;
        output = 1;
    } else {
        return 92;
    }
    errno = EDOM;
    uint64_t result[2];
    if (phase2_abi_probe_result(target, arguments, result) || errno != EDOM)
        return 11;
    if (allocation) {
        uintptr_t pointer = output ? (uintptr_t)out : result[0];
        if (!pointer || pointer % alignment || (output && ((uint32_t)result[0] || out == &out)))
            return 12;
        free((void *)pointer);
    }
    return 0;
}
