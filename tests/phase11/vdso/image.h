#ifndef OA_TEST_VDSO_IMAGE_H
#define OA_TEST_VDSO_IMAGE_H

#include <stddef.h>
#include <stdint.h>
#include <string.h>

enum {
    PAGE_SIZE = 4096, LOAD_HEADER = 64, DYNAMIC_HEADER = 120,
    DYNAMIC = 0x100, STRINGS = 0x200, HASH = 0x240, SYMBOLS = 0x260,
    VERSIONS = 0x2a0, DEFINITION = 0x2b0, ENTRY = 0x380,
};

static void word(unsigned char *at, uint64_t value, unsigned size)
{
    for (unsigned index = 0; index < size; ++index) {
        at[index] = (unsigned char)value;
        value >>= 8;
    }
}

static unsigned elf_hash(const char *text)
{
    unsigned hash = 0;
    for (; *text; ++text) {
        hash = (hash << 4) + (unsigned char)*text;
        unsigned high = hash & 0xf0000000u;
        hash = (hash ^ (high >> 24)) & ~high;
    }
    return hash;
}

static void fixture_image(unsigned char image[PAGE_SIZE], unsigned entry_size)
{
    static const unsigned char ident[] = {0x7f, 'E', 'L', 'F', 2, 1, 1};
    static const char symbol[] = "__vdso_clock_gettime";
    static const char version[] = "LINUX_2.6";
    enum { SYMBOL_NAME = 1, VERSION_NAME = SYMBOL_NAME + sizeof symbol };
    static const uint64_t dynamic[][2] = {
        {4, HASH}, {5, STRINGS}, {6, SYMBOLS}, {10, VERSION_NAME + sizeof version}, {11, 24},
        {0x6ffffff0, VERSIONS}, {0x6ffffffc, DEFINITION}, {0x6ffffffd, 1}, {0, 0},
    };

    memset(image, 0, PAGE_SIZE);
    memcpy(image, ident, sizeof ident);
    word(image + 16, 3, 2);                 /* ET_DYN */
    word(image + 18, 62, 2);                /* EM_X86_64 */
    word(image + 20, 1, 4);                 /* EV_CURRENT */
    word(image + 32, LOAD_HEADER, 8);       /* e_phoff */
    word(image + 52, LOAD_HEADER, 2);       /* e_ehsize */
    word(image + 54, 56, 2);                /* e_phentsize */
    word(image + 56, 2, 2);                 /* e_phnum */

    word(image + LOAD_HEADER, 1, 4);        /* PT_LOAD */
    word(image + LOAD_HEADER + 4, 5, 4);    /* PF_R | PF_X */
    word(image + LOAD_HEADER + 32, PAGE_SIZE, 8);
    word(image + LOAD_HEADER + 40, PAGE_SIZE, 8);
    word(image + LOAD_HEADER + 48, PAGE_SIZE, 8);

    word(image + DYNAMIC_HEADER, 2, 4);     /* PT_DYNAMIC */
    word(image + DYNAMIC_HEADER + 4, 4, 4);
    word(image + DYNAMIC_HEADER + 8, DYNAMIC, 8);
    word(image + DYNAMIC_HEADER + 16, DYNAMIC, 8);
    word(image + DYNAMIC_HEADER + 32, sizeof dynamic, 8);
    word(image + DYNAMIC_HEADER + 40, sizeof dynamic, 8);
    word(image + DYNAMIC_HEADER + 48, 8, 8);
    for (size_t row = 0; row < sizeof dynamic / sizeof dynamic[0]; ++row) {
        word(image + DYNAMIC + 16 * row, dynamic[row][0], 8);
        word(image + DYNAMIC + 16 * row + 8, dynamic[row][1], 8);
    }

    memcpy(image + STRINGS + SYMBOL_NAME, symbol, sizeof symbol);
    memcpy(image + STRINGS + VERSION_NAME, version, sizeof version);
    word(image + HASH, 1, 4);              /* One bucket, two symbols. */
    word(image + HASH + 4, 2, 4);
    word(image + HASH + 8, 1, 4);          /* Bucket points at symbol 1. */

    unsigned char *entry_symbol = image + SYMBOLS + 24;
    word(entry_symbol, SYMBOL_NAME, 4);
    entry_symbol[4] = 0x12;                /* STB_GLOBAL | STT_FUNC */
    word(entry_symbol + 6, 1, 2);           /* Defined in section 1. */
    word(entry_symbol + 8, ENTRY, 8);
    word(entry_symbol + 16, entry_size, 8);

    word(image + VERSIONS + 2, 2, 2);
    word(image + DEFINITION, 1, 2);         /* VER_DEF_CURRENT */
    word(image + DEFINITION + 4, 2, 2);
    word(image + DEFINITION + 6, 1, 2);
    word(image + DEFINITION + 8, elf_hash(version), 4);
    word(image + DEFINITION + 12, 20, 4);
    word(image + DEFINITION + 20, VERSION_NAME, 4);
    image[ENTRY] = 0xc3;                   /* x86-64 ret */
}

#endif
