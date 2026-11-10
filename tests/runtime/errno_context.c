#include <asm/prctl.h>
#include <errno.h>
#include <stddef.h>
#include <stdint.h>

#include "linux_abi.h"

/* Linux ARCH_SET_FS plus the project's AMD64 thread-control-block ABI. */
struct thread_block {
    uintptr_t self;
    uint64_t reserved;
    uintptr_t descriptor_self;
    uint64_t padding[5];
    int cell;
};

_Static_assert(offsetof(struct thread_block, cell) == 0x40, "errno ABI offset");
static _Alignas(64) struct thread_block first, second;
static int *(*volatile locate)(void) = __errno_location;
extern unsigned phase2_abi_probe(uintptr_t function, const uint64_t arguments[6]);

static int exercise(struct thread_block *block, uintptr_t original_fs,
                    int expected_before, int replacement, int check_abi)
{
    block->self = block->descriptor_self = (uintptr_t)block;
    if (__al_syscall(__NR_arch_prctl, ARCH_SET_FS, (long)block, 0, 0, 0, 0) != 0)
        return 22;

    int *cell = locate();
    int before = 0, after = 0;
    int *again = NULL;
    unsigned abi = 0;
    if (cell == &block->cell) {
        before = *cell;
        *cell = replacement;
        again = locate();
        if (again == &block->cell)
            after = *again;
    }
    if (check_abi)
        abi = phase2_abi_probe((uintptr_t)__errno_location, (const uint64_t[6]){0});

    if (__al_syscall(__NR_arch_prctl, ARCH_SET_FS, (long)original_fs, 0, 0, 0, 0) != 0) {
        __al_syscall(__NR_exit_group, 23, 0, 0, 0, 0, 0);
        __builtin_trap();
    }
    /* An incorrect pointer is rejected without dereferencing it. */
    if (cell != &block->cell || again != &block->cell)
        return 31;
    if (before != expected_before || after != replacement)
        return 32;
    return abi ? 33 : 0;
}

int main(int argc, char **argv)
{
    if (argc != 1 && (argc != 2 || argv[1][0] != 'a'))
        return 20;
    uintptr_t original_fs = 0;
    if (__al_syscall(__NR_arch_prctl, ARCH_GET_FS, (long)&original_fs, 0, 0, 0, 0) != 0 || !original_fs)
        return 21;
    int *original = locate();
    if ((uintptr_t)original != original_fs + 0x40)
        return 31;
    *original = 117;
    first.cell = -91321;
    second.cell = 0x12345678;

    int status = exercise(&first, original_fs, -91321, 0x34567890, argc == 2);
    if (status)
        return status;
    status = exercise(&second, original_fs, 0x12345678, -50503, argc == 2);
    if (status)
        return status;
    status = exercise(&first, original_fs, 0x34567890, -111, argc == 2);
    if (status)
        return status;
    if (locate() != original || *original != 117 || first.cell != -111 || second.cell != -50503)
        return 34;
    return 0;
}
