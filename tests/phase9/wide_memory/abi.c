#include "fixture.h"

extern unsigned phase2_abi_probe_result(uintptr_t, const uint64_t[6], uint64_t[2]);

enum { MARK = 0x31415926 };

static int probe(uintptr_t function, const uint64_t arguments[6], uint64_t expected, int comparison)
{
    uint64_t actual[2] = {UINT64_MAX, UINT64_MAX};
    errno = TEST_ERRNO;
    if (phase2_abi_probe_result(function, arguments, actual))
        return 11;
    if (comparison) {
        uint32_t low = (uint32_t)actual[0];
        actual[0] = low ? (low & UINT32_C(0x80000000) ? UINT64_MAX : 1) : 0;
    }
    return actual[0] == expected && errno == TEST_ERRNO ? 0 : 12;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    enum operation operation = operation_from(argv[1]);
    if (operation == OPERATIONS)
        return 90;
    const wchar_t original[] = {MARK, WCHAR_MIN, 0, -1, WCHAR_MAX, 0x1000000, MARK, MARK};
    const wchar_t other[] = {MARK, WCHAR_MAX, 0, 1, WCHAR_MIN, 0x1000000, MARK, MARK};
    wchar_t a[8], b[8], expected[8];
    for (size_t i = 0; i < 8; ++i) {
        a[i] = original[i];
        b[i] = expected[i] = other[i];
    }
    uint64_t args[6] = {(uintptr_t)(a + 1), (uintptr_t)(b + 1), 5,
        UINT64_C(0xe5bdb419284dbc63), UINT64_C(0x7756e9743bc1a5f8), UINT64_C(0x54be8efa37e66cf9)};
    int result = 0;
    if (operation == CMP) {
        result = probe((uintptr_t)wmemcmp, args, UINT64_MAX, 1);
        args[0] = (uintptr_t)(b + 1);
        args[1] = (uintptr_t)(a + 1);
        if (!result)
            result = probe((uintptr_t)wmemcmp, args, 1, 1);
        args[2] = 0;
        if (!result)
            result = probe((uintptr_t)wmemcmp, args, 0, 1);
        args[0] = args[1] = (uintptr_t)(a + 2);
        args[2] = 4;
        if (!result)
            result = probe((uintptr_t)wmemcmp, args, 0, 1);
    } else if (operation == COPY) {
        args[0] = (uintptr_t)(b + 1);
        args[1] = (uintptr_t)(a + 1);
        for (size_t i = 1; i <= 5; ++i)
            expected[i] = original[i];
        result = probe((uintptr_t)wmemcpy, args, (uintptr_t)(b + 1), 0);
        args[2] = 0;
        if (!result)
            result = probe((uintptr_t)wmemcpy, args, (uintptr_t)(b + 1), 0);
    } else if (operation == MOVE) {
        args[0] = (uintptr_t)(b + 2);
        args[1] = (uintptr_t)(b + 1);
        args[2] = 4;
        for (size_t i = 0; i < 4; ++i)
            expected[i + 2] = other[i + 1];
        result = probe((uintptr_t)wmemmove, args, (uintptr_t)(b + 2), 0);
        if (!result && !same_wide(b, expected, 8))
            result = 13;
        for (size_t i = 0; i < 8; ++i)
            b[i] = expected[i] = other[i];
        args[0] = (uintptr_t)(b + 1);
        args[1] = (uintptr_t)(b + 2);
        for (size_t i = 0; i < 4; ++i)
            expected[i + 1] = other[i + 2];
        if (!result)
            result = probe((uintptr_t)wmemmove, args, (uintptr_t)(b + 1), 0);
        args[1] = args[0];
        if (!result)
            result = probe((uintptr_t)wmemmove, args, (uintptr_t)(b + 1), 0);
        args[2] = 0;
        if (!result)
            result = probe((uintptr_t)wmemmove, args, (uintptr_t)(b + 1), 0);
    } else {
        const uint64_t values[] = {UINT64_C(0xa581db15ffffffff), UINT64_C(0x1431b5a280000000),
                                   UINT64_C(0x81fa16be01000000), UINT64_C(0x7f741bf900000000)};
        args[0] = (uintptr_t)(b + 1);
        for (size_t j = 0; !result && j < sizeof values / sizeof *values; ++j) {
            args[1] = values[j];
            for (size_t i = 1; i <= 5; ++i)
                expected[i] = element((uint32_t)values[j]);
            result = probe((uintptr_t)wmemset, args, (uintptr_t)(b + 1), 0);
            if (!result && !same_wide(b, expected, 8))
                result = 13;
        }
        args[2] = 0;
        if (!result)
            result = probe((uintptr_t)wmemset, args, (uintptr_t)(b + 1), 0);
    }
    if (!result && (!same_wide(a, original, 8) || !same_wide(b, expected, 8)))
        result = 13;
    return result;
}
