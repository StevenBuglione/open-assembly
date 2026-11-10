#include "fixture.h"

extern unsigned phase2_abi_probe_result(uintptr_t, const uint64_t[6], uint64_t[2]);

enum { MARK = 0x31415926 };

static int probe(uintptr_t target, const uint64_t arguments[6], const wchar_t *expected)
{
    uint64_t result[2] = {UINT64_MAX, UINT64_MAX};
    errno = TEST_ERRNO;
    if (phase2_abi_probe_result(target, arguments, result))
        return 11;
    return result[0] == (uintptr_t)expected && errno == TEST_ERRNO ? 0 : 12;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    enum operation operation = operation_from(argv[1]);
    if (operation == OPERATIONS)
        return 90;
    const wchar_t original[] = {MARK, -1, WCHAR_MIN, -1, 0, WCHAR_MAX, 0, 0, 0, 0};
    wchar_t source[10], destination[10], expected[10];
    for (size_t i = 0; i < 10; ++i) {
        source[i] = original[i];
        destination[i] = expected[i] = MARK;
    }
    uint64_t arguments[6] = {
        (uintptr_t)(source + 1), UINT64_C(0x94ddc3faffffffff),
        UINT64_C(0x746e6ec62980aca4), UINT64_C(0x84f496315ab9c729),
        UINT64_C(0x9291fd6c37a937e9), UINT64_C(0x79d2452742097251)
    };
    int result;
    if (operation == FIRST || operation == LAST) {
        uintptr_t function = operation == FIRST ? (uintptr_t)wcschr : (uintptr_t)wcsrchr;
        result = probe(function, arguments, source + (operation == FIRST ? 1 : 3));
        arguments[1] = UINT64_C(0x1f34ac5e00000000);
        if (!result)
            result = probe(function, arguments, source + 4);
        arguments[1] = UINT64_C(0x8adab29e80000000);
        if (!result)
            result = probe(function, arguments, source + 2);
        arguments[1] = UINT64_C(0xf21083f57fffffff);
        if (!result)
            result = probe(function, arguments, NULL);
    } else {
        uintptr_t function = operation == COPY ? (uintptr_t)wcscpy : (uintptr_t)wcsncpy;
        arguments[0] = (uintptr_t)(destination + 1);
        arguments[1] = (uintptr_t)(source + 1);
        arguments[2] = 0;
        result = operation == NCOPY ? probe(function, arguments, destination + 1) : 0;
        if (!result && !same_wide(destination, expected, 10))
            result = 13;
        if (!result && operation == NCOPY) {
            arguments[2] = 2;
            expected[1] = -1;
            expected[2] = WCHAR_MIN;
            result = probe(function, arguments, destination + 1);
            if (!result && !same_wide(destination, expected, 10))
                result = 13;
        }
        arguments[2] = 7;
        for (size_t i = 1; i <= (operation == COPY ? 4U : 7U); ++i)
            expected[i] = i < 4 ? original[i] : 0;
        if (!result)
            result = probe(function, arguments, destination + 1);
    }
    if (!result && (!same_wide(source, original, 10) || !same_wide(destination, expected, 10)))
        result = 13;
    return result;
}
