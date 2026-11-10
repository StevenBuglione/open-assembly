#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

extern size_t __al_test_strlen(const char *input);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    /* Oracle reference:byte-count (C17 7.24.6.3). */
    char bytes[8193];
    if (size >= sizeof bytes)
        size = sizeof bytes - 1;
    size_t first_zero = size;
    for (size_t i = 0; i < size; ++i) {
        bytes[i] = (char)data[i];
        if (!data[i] && first_zero == size)
            first_zero = i;
    }
    bytes[size] = 0;
    if (__al_test_strlen(bytes) != first_zero)
        abort();
    return 0;
}
