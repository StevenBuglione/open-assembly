#include "fixture.h"

extern unsigned phase2_abi_probe_result(uintptr_t, const uint64_t[6], uint64_t[2]);

enum { MARK = 0x31415926 };

static int probe(uintptr_t function, const uint64_t args[6], uint64_t expected)
{
    uint64_t actual[2] = {UINT64_MAX, UINT64_MAX};
    errno = TEST_ERRNO;
    if (phase2_abi_probe_result(function, args, actual))
        return 11;
    return actual[0] == expected && errno == TEST_ERRNO ? 0 : 12;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    enum operation operation = operation_from(argv[1]);
    if (operation == OPERATIONS)
        return 90;
    const wchar_t original_a[] = {MARK, WCHAR_MIN, -1, WCHAR_MIN, 0x1000000, 0, WCHAR_MIN, 0};
    const wchar_t original_b[] = {MARK, WCHAR_MIN, -1, 0, 0x1000000, 0, MARK, MARK};
    const wchar_t original_c[] = {MARK, 0x1000000, 0, WCHAR_MIN, 0, MARK, MARK, MARK};
    const wchar_t original_d[] = {MARK, -1, WCHAR_MIN, 0x1000000, 0, MARK, MARK, MARK};
    wchar_t a[8], b[8], c[8], d[8];
    for (size_t i = 0; i < 8; ++i) {
        a[i] = original_a[i];
        b[i] = original_b[i];
        c[i] = original_c[i];
        d[i] = original_d[i];
    }
    uint64_t args[6] = {(uintptr_t)(a + 1), (uintptr_t)(b + 1),
        UINT64_C(0xb1f47c5be8631fd8), UINT64_C(0xd37fe7196cbb4753),
        UINT64_C(0x29b3dc735f90ba61), UINT64_C(0xc2867f49718d8baf)};
    uintptr_t function;
    uint64_t first, empty;
    if (operation == SPAN) {
        function = (uintptr_t)wcsspn;
        first = 3;
        empty = 0;
    } else if (operation == CSPAN) {
        function = (uintptr_t)wcscspn;
        args[1] = (uintptr_t)(c + 1);
        first = 3;
        empty = 4;
    } else if (operation == BREAK) {
        function = (uintptr_t)wcspbrk;
        args[1] = (uintptr_t)(c + 1);
        first = (uintptr_t)(a + 4);
        empty = 0;
    } else {
        function = (uintptr_t)wcsstr;
        args[1] = (uintptr_t)(d + 1);
        first = (uintptr_t)(a + 2);
        empty = (uintptr_t)(a + 1);
    }
    int result = probe(function, args, first);
    args[1] = (uintptr_t)(b + 3);
    if (!result)
        result = probe(function, args, empty);
    args[0] = (uintptr_t)(a + 5);
    args[1] = operation == FIND ? (uintptr_t)(d + 1) : (uintptr_t)(b + 1);
    if (!result)
        result = probe(function, args, 0);
    if (!result && (!same_wide(a, original_a, 8) || !same_wide(b, original_b, 8) ||
                    !same_wide(c, original_c, 8) || !same_wide(d, original_d, 8)))
        result = 13;
    return result;
}
