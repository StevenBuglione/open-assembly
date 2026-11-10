#include <errno.h>
#include <fenv.h>
#include <float.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

#include "fp_machine.h"

enum { HEADER_SIZE = 24, MAX_INPUT = 24000, SENTINEL_ERRNO = 947 };
enum target { BINARY32, BINARY64, BINARY80, ATOF };

_Static_assert(FLT_MANT_DIG == 24 && DBL_MANT_DIG == 53 && LDBL_MANT_DIG == 64,
               "the test compares x86 floating-point representations");
_Static_assert(sizeof(long double) == 16, "SysV AMD64 long double storage");

static char text[MAX_INPUT + 1];

static uint64_t little_endian(const unsigned char *bytes, size_t size)
{
    uint64_t value = 0;
    for (size_t i = 0; i < size; ++i)
        value |= (uint64_t)bytes[i] << (8 * i);
    return value;
}

static int read_exact(void *destination, size_t size)
{
    unsigned char *bytes = destination;
    size_t total = 0;
    while (total < size) {
        ssize_t count = read(STDIN_FILENO, bytes + total, size - total);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            return count == 0 && total == 0 ? 0 : -1;
        total += (size_t)count;
    }
    return 1;
}

static char *append_number(char *destination, size_t number)
{
    char digits[24];
    size_t count = 0;
    do {
        digits[count++] = (char)('0' + number % 10);
        number /= 10;
    } while (number);
    while (count)
        *destination++ = digits[--count];
    return destination;
}

static int fail(size_t row, int status)
{
    char message[64];
    char *end = message;
    for (const char *p = "record "; *p; ++p)
        *end++ = *p;
    end = append_number(end, row);
    for (const char *p = " status "; *p; ++p)
        *end++ = *p;
    end = append_number(end, (size_t)status);
    *end++ = '\n';
    if (write(STDERR_FILENO, message, (size_t)(end - message)) != end - message)
        return 99;
    return status;
}

static int conversion(enum target target, const unsigned char *header, int bits_only)
{
    size_t wanted_end = (size_t)little_endian(header + 4, 4);
    unsigned short rounding = (unsigned short)little_endian(header + 8, 2);
    unsigned short flags = (unsigned short)little_endian(header + 10, 2);
    int error = (int)little_endian(header + 12, 2);
    uint16_t wanted_high = (uint16_t)little_endian(header + 14, 2);
    uint64_t wanted_low = little_endian(header + 16, 8);

    struct machine_fenv original = observe();
    unsigned short control = (unsigned short)((original.control & ~0x0c00u) | rounding);
    unsigned int mxcsr = (original.mxcsr & ~(0x6000u | 0x3fu)) | ((unsigned int)rounding << 3)
        | FE_DIVBYZERO;
    install(control, mxcsr);
    volatile int *error_cell = __errno_location();
    *error_cell = SENTINEL_ERRNO;
    char *end = NULL;
    uint64_t low;
    uint16_t high = 0;
    if (target == BINARY32) {
        union { float value; uint32_t bits; } result;
        result.value = strtof(text, &end);
        low = result.bits;
    } else if (target == BINARY80) {
        union { long double value; unsigned char bytes[16]; } result;
        result.value = strtold(text, &end);
        low = little_endian(result.bytes, 8);
        high = (uint16_t)little_endian(result.bytes + 8, 2);
    } else {
        union { double value; uint64_t bits; } result;
        if (target == ATOF) {
            result.value = atof(text);
        } else {
            result.value = strtod(text, &end);
        }
        low = result.bits;
    }
    struct machine_fenv observed = observe();
    int reported_error = *error_cell;
    install(original.control, original.mxcsr);

    if (target != ATOF && end != text + wanted_end)
        return 20;
    if (low != wanted_low || high != wanted_high)
        return 21;
    if (bits_only)
        return 0;
    if (reported_error != (error ? error : SENTINEL_ERRNO))
        return 22;
    if (((observed.status | observed.mxcsr) & FE_ALL_EXCEPT) != (unsigned int)(flags | FE_DIVBYZERO))
        return 23;
    if (observed.control != control || (observed.mxcsr & ~0x3fu) != (mxcsr & ~0x3fu))
        return 24;
    return 0;
}

static int equal(const char *a, const char *b)
{
    while (*a && *a == *b) {
        ++a;
        ++b;
    }
    return *a == *b;
}

int main(int argc, char **argv)
{
    if ((argc != 2 && argc != 3) || (argc == 3 && !equal(argv[2], "bits")))
        return 9;
    enum target target;
    if (equal(argv[1], "f32"))
        target = BINARY32;
    else if (equal(argv[1], "f64"))
        target = BINARY64;
    else if (equal(argv[1], "f80"))
        target = BINARY80;
    else if (equal(argv[1], "atof"))
        target = ATOF;
    else
        return 9;

    size_t row = 0;
    unsigned char header[HEADER_SIZE];
    for (;;) {
        int input = read_exact(header, sizeof header);
        if (input == 0)
            break;
        if (input < 0)
            return fail(row, 10);
        size_t length = (size_t)little_endian(header, 4);
        if (length > MAX_INPUT || little_endian(header + 4, 4) > length
                || read_exact(text, length) != 1)
            return fail(row, 11);
        text[length] = '\0';
        int status = conversion(target, header, argc == 3);
        if (status)
            return fail(row, status);
        ++row;
    }
    if (!row)
        return 12;
    char count[25], *end = append_number(count, row);
    *end++ = '\n';
    return write(STDOUT_FILENO, count, (size_t)(end - count)) == end - count ? 0 : 99;
}
