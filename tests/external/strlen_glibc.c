/*
 * Oracle diff:glibc. Compile and link independently of the candidate, with
 * -ffreestanding -fno-builtin and the pinned glibc toolchain.
 *
 * Protocol on x86-64: uint32_t byte count, that many bytes ending in NUL,
 * then uint64_t length in the response. The host object references strlen.
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#ifndef __GLIBC__
#error "This oracle must link against glibc"
#endif

int main(void)
{
    char bytes[8193];
    for (;;) {
        uint32_t size;
        size_t received = fread(&size, 1, sizeof size, stdin);
        if (received == 0 && feof(stdin))
            return 0;
        if (received != sizeof size || size == 0 || size > sizeof bytes ||
            fread(bytes, 1, size, stdin) != size || bytes[size - 1] != '\0') {
            fputs("glibc strlen oracle received an invalid request\n", stderr);
            return 2;
        }

        uint64_t length = strlen(bytes);
        if (fwrite(&length, 1, sizeof length, stdout) != sizeof length ||
            fflush(stdout) == EOF)
            return 2;
    }
}
