#include <asm/prctl.h>
#include <elf.h>
#include <errno.h>
#include <stdint.h>

#include "linux_abi.h"

extern void _start(void);
extern char **const __al_initial_envp;
extern const Elf64_auxv_t *const __al_auxv;

static _Thread_local volatile unsigned char initialized[7]
    __attribute__((aligned(64), tls_model("local-exec"))) = {7, 0, 9, 231, 4, 3, 193};
static _Thread_local volatile unsigned char zeroed[80]
    __attribute__((aligned(256), tls_model("local-exec")));

static int same_string(const char *actual, const char *expected)
{
    if (!actual)
        return 0;
    while (*actual && *actual == *expected) {
        ++actual;
        ++expected;
    }
    return *actual == *expected;
}

static int starts_with(const char *actual, const char *prefix)
{
    while (*prefix)
        if (*actual++ != *prefix++)
            return 0;
    return 1;
}

static uint64_t little_endian_word(const unsigned char *bytes)
{
    uint64_t word = 0;
    for (unsigned int i = 0; i < sizeof word; ++i)
        word |= (uint64_t)bytes[i] << (8 * i);
    return word;
}

int main(int argc, char **argv, char **envp)
{
    if ((argc != 1 && argc != 4 && argc != 5) || !argv || !argv[0] || !argv[0][0] || argv[argc])
        return 20;
    if (argc >= 4 && (!same_string(argv[1], "arg with spaces")
                      || !same_string(argv[2], "") || !same_string(argv[3], "--value=a=b")))
        return 21;
    if (argc == 5 && !same_string(argv[4], "expect-valgrind-preload"))
        return 21;
    if (envp != argv + argc + 1 || envp != __al_initial_envp)
        return 22;
    unsigned int env_count = argc > 1 ? (unsigned int)argc - 2 : 0;
    int found_value = 0, found_empty = 0, found_preload = 0;
    unsigned int i;
    for (i = 0; i < env_count && envp[i]; ++i) {
        found_value += same_string(envp[i], "OA_PHASE1_VALUE=one two");
        found_empty += same_string(envp[i], "OA_PHASE1_EMPTY=");
        found_preload += starts_with(envp[i], "LD_PRELOAD=");
    }
    if (i != env_count || envp[env_count])
        return 24;
    if (found_value != (argc >= 4) || found_empty != (argc >= 4) || found_preload != (argc == 5))
        return 23;

    const Elf64_auxv_t *auxv = (const Elf64_auxv_t *)(envp + env_count + 1);
    if (auxv != __al_auxv)
        return 25;
    const unsigned char *random_bytes = 0;
    uintptr_t entry = 0;
    unsigned long page_size = 0;
    for (i = 0; i < 128 && auxv[i].a_type != AT_NULL; ++i) {
        if (auxv[i].a_type == AT_RANDOM)
            random_bytes = (const unsigned char *)auxv[i].a_un.a_val;
        if (auxv[i].a_type == AT_ENTRY)
            entry = auxv[i].a_un.a_val;
        if (auxv[i].a_type == AT_PAGESZ)
            page_size = auxv[i].a_un.a_val;
    }
    if (i == 128 || !random_bytes || entry != (uintptr_t)&_start
            || !page_size || (page_size & (page_size - 1)))
        return 26;

    uintptr_t fs_base = 0;
    if (__al_syscall(__NR_arch_prctl, ARCH_GET_FS, (long)&fs_base, 0, 0, 0, 0) != 0)
        return 27;
    uintptr_t self, descriptor_self;
    uint64_t guard, pointer_guard;
    __asm__ volatile ("movq %%fs:0, %0" : "=r" (self));
    __asm__ volatile ("movq %%fs:0x10, %0" : "=r" (descriptor_self));
    __asm__ volatile ("movq %%fs:0x28, %0" : "=r" (guard));
    __asm__ volatile ("movq %%fs:0x30, %0" : "=r" (pointer_guard));
    if (!self || self != fs_base || self != descriptor_self)
        return 28;
    if (guard != (little_endian_word(random_bytes) & ~UINT64_C(0xff)))
        return 29;
    if (pointer_guard != little_endian_word(random_bytes + 8))
        return 30;

    int *(*volatile locate_errno)(void) = __errno_location;
    int *error_cell = locate_errno();
    if ((uintptr_t)error_cell != self + 0x40 || error_cell != locate_errno())
        return 31;
    if (*error_cell != 0)
        return 32;

    if ((uintptr_t)&initialized % 64 || (uintptr_t)&zeroed % 256
            || (uintptr_t)&initialized >= self || (uintptr_t)&zeroed >= self)
        return 33;
    static const unsigned char expected[] = {7, 0, 9, 231, 4, 3, 193};
    for (i = 0; i < sizeof expected; ++i)
        if (initialized[i] != expected[i])
            return 34;
    for (i = 0; i < sizeof zeroed; ++i)
        if (zeroed[i] != 0)
            return 35;

    *error_cell = 1234;
    initialized[3] = 198;
    zeroed[sizeof zeroed - 1] = 39;
    if (errno != 1234 || initialized[3] != 198 || zeroed[sizeof zeroed - 1] != 39)
        return 36;
    return 0;
}
