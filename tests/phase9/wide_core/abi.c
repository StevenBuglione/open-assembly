#include "fixture.h"

extern unsigned phase2_abi_probe_result(uintptr_t, const uint64_t[6], uint64_t[2]);

static int probe(uintptr_t target, const uint64_t arguments[6], uint64_t expected, int comparison)
{
    uint64_t actual[2] = {UINT64_MAX, UINT64_MAX};
    errno = TEST_ERRNO;
    if (phase2_abi_probe_result(target, arguments, actual))
        return 11;
    if (comparison) {
        uint32_t low = (uint32_t)actual[0];
        int order = low ? (low & UINT32_C(0x80000000) ? -1 : 1) : 0;
        actual[0] = (uint64_t)(int64_t)order;
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
    const wchar_t original_a[] = {0x31415926, 1, -1, WCHAR_MIN, 0, -1, 0, 0, 0, 0};
    const wchar_t original_b[] = {0x27182818, 1, WCHAR_MAX, 7, 0, 0, 0, 0, 0, 0};
    wchar_t a[10], b[10];
    for (size_t i = 0; i < 10; ++i) {
        a[i] = original_a[i];
        b[i] = original_b[i];
    }
    uint64_t args[6] = {(uintptr_t)(a + 1), (uintptr_t)(b + 1), SIZE_MAX,
                        UINT64_C(0x1b5687a2ae27ed10), UINT64_C(0xa5a523a387702dc9),
                        UINT64_C(0xa64eae7bba987c29)};
    int result;
    if (operation == LEN) {
        result = probe((uintptr_t)wcslen, args, 3, 0);
        args[0] = (uintptr_t)(a + 4);
        if (!result)
            result = probe((uintptr_t)wcslen, args, 0, 0);
    } else if (operation == CHR) {
        args[1] = UINT64_C(0xa53617b9ffffffff);
        args[2] = 5;
        result = probe((uintptr_t)wmemchr, args, (uintptr_t)(a + 2), 0);
        args[1] = UINT64_C(0xfefe13b980000000);
        args[2] = 2;
        if (!result)
            result = probe((uintptr_t)wmemchr, args, 0, 0);
        args[2] = 3;
        if (!result)
            result = probe((uintptr_t)wmemchr, args, (uintptr_t)(a + 3), 0);
    } else {
        uintptr_t target = operation == CMP ? (uintptr_t)wcscmp : (uintptr_t)wcsncmp;
        result = probe(target, args, UINT64_MAX, 1);
        args[0] = (uintptr_t)(b + 1);
        args[1] = (uintptr_t)(a + 1);
        if (!result)
            result = probe(target, args, 1, 1);
        if (operation == CMP)
            args[0] = args[1];
        else
            args[2] = 1;
        if (!result)
            result = probe(target, args, 0, 1);
    }
    if (!result && (!same_wide(a, original_a, 10) || !same_wide(b, original_b, 10)))
        result = 13;
    return result;
}
