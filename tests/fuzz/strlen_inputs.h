#ifndef AL_TEST_STRLEN_INPUTS_H
#define AL_TEST_STRLEN_INPUTS_H

#include <stddef.h>
#include <stdint.h>

#define STRLEN_FUZZ_SEED UINT32_C(0x41534d30)
#define STRLEN_FUZZ_MIN_CASES 2048
#define STRLEN_FUZZ_MAX_BYTES 8193
#define STRLEN_FUZZ_ALIGNMENTS 64

struct strlen_fuzz_input {
    unsigned char storage[STRLEN_FUZZ_MAX_BYTES + STRLEN_FUZZ_ALIGNMENTS - 1];
    unsigned char *bytes;
    size_t size;
    size_t first_zero;
};

static uint32_t next_word(uint32_t *state)
{
    /* The seed is nonzero, so this xorshift32 sequence never sticks at zero. */
    uint32_t value = *state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    *state = value;
    return value;
}

static void generate_input(struct strlen_fuzz_input *input, uint32_t *state, size_t index)
{
    static const size_t boundaries[] = {
        1, 2, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65,
        127, 128, 129, 255, 256, 257, 511, 512, 513,
        1023, 1024, 1025, 4095, 4096, 4097, 8193,
    };

    input->bytes = input->storage + next_word(state) % STRLEN_FUZZ_ALIGNMENTS;
    if (index % 4 == 0)
        input->size = boundaries[(index / 4) % (sizeof boundaries / sizeof boundaries[0])];
    else
        input->size = 1 + next_word(state) % STRLEN_FUZZ_MAX_BYTES;

    /* Oracle reference:byte-count. Every prefix byte is constructed nonzero. */
    input->first_zero = index % 8 == 0 ? input->size - 1 : next_word(state) % input->size;
    for (size_t i = 0; i < input->first_zero; i++)
        input->bytes[i] = 1 + next_word(state) % 255;
    input->bytes[input->first_zero] = 0;
    for (size_t i = input->first_zero + 1; i < input->size; i++)
        input->bytes[i] = (unsigned char)next_word(state);
    input->bytes[input->size - 1] = 0;
}

#endif
