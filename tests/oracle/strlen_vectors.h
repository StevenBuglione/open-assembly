#ifndef AL_TEST_STRLEN_VECTORS_H
#define AL_TEST_STRLEN_VECTORS_H

#include <stddef.h>

/*
 * Oracle reference:byte-count (C17 7.24.6.3).
 * Expected values count the explicitly listed bytes before the first zero.
 */
static const struct {
    const char *name;
    const char *bytes;
    size_t expected;
} strlen_vectors[] = {
    {"empty", "", 0},
    {"one byte", "x", 1},
    {"ASCII phrase", "open assembly", 13},
    {"prefix before embedded zero", "abc\0suffix", 3},
    {"leading zero with suffix", "\0nonempty", 0},
    {"two embedded zeros", "x\0y\0z", 1},
    {"control bytes", "\x01\x09\x0a\x0d\x1b\x7f", 6},
    {"high-bit bytes", "\x80\xa5\xfe\xff", 4},
    {"zero between high-bit bytes", "\xff\x80\x00\x81\xff", 2},
    {"seven bytes", "1234567", 7},
    {"eight bytes", "12345678", 8},
    {"nine bytes", "123456789", 9},
    {"sixteen bytes", "0123456789abcdef", 16},
    {"thirty-two bytes", "0123456789abcdef" "0123456789abcdef", 32},
};

#endif
