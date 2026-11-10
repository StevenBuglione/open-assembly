#include "child.h"

extern unsigned phase2_abi_probe_result(uintptr_t, const uint64_t[6], uint64_t[2]);

static int observe_abi(int specific, pid_t selector, int options, pid_t expected,
                       int expected_status, int expected_errno)
{
    struct status_box box = boxed(STATUS_SENTINEL);
    uintptr_t function = specific ? (uintptr_t)waitpid : (uintptr_t)wait;
    uint64_t args[6] = {
        (uintptr_t)&box.status, UINT64_C(0x031577b9ca1fe343),
        UINT64_C(0x8879e34a943f357c), UINT64_C(0x3cd2a66f7a15ed23),
        UINT64_C(0x7b63dc9542d3458a), UINT64_C(0x823feaa1d42590bc)
    };
    if (specific) {
        args[0] = UINT64_C(0xf97ea66100000000) | (uint32_t)selector;
        args[1] = (uintptr_t)&box.status;
        args[2] = UINT64_C(0xbadfaed100000000) | (uint32_t)options;
    }
    uint64_t result[2] = {UINT64_MAX, UINT64_MAX};
    errno = TEST_ERRNO;
    if (phase2_abi_probe_result(function, args, result))
        return 11;
    if ((uint32_t)result[0] != (uint32_t)expected || errno != expected_errno)
        return 12;
    if (!guarded(&box) || box.status != expected_status)
        return 13;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    int specific = same_text(argv[1], "waitpid");
    if (!specific && !same_text(argv[1], "wait"))
        return 90;
    struct child child = {0, -1};
    if (!start_child(&child, 73, specific))
        return 91;
    int result = 0;
    if (specific) {
        result = observe_abi(1, child.pid, WNOHANG, 0, STATUS_SENTINEL, TEST_ERRNO);
        if (!result)
            result = observe_abi(1, child.pid, INVALID_WAIT_FLAGS, -1, STATUS_SENTINEL, EINVAL);
        if (!result && !release_child(&child))
            result = 92;
    }
    if (!result)
        result = observe_abi(specific, -1, 0, child.pid, 73 << 8, TEST_ERRNO);
    if (!result && !reaped(&child))
        result = 14;
    if (!result)
        result = observe_abi(specific, -1, 0, -1, STATUS_SENTINEL, ECHILD);
    return clean_child(&child) ? result : 93;
}
