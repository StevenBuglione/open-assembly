#include "endpoint.h"

extern unsigned phase2_abi_probe_result(uintptr_t target, const uint64_t arguments[6],
                                        uint64_t result[2]);

int main(void)
{
    static const int flags[] = {0, O_CLOEXEC, O_NONBLOCK, O_CLOEXEC | O_NONBLOCK, -1};
    static const uint64_t poison = UINT64_C(0x8ce52b9700000000);
    static const uint64_t before = UINT64_C(0x718f44b289130cad), after = UINT64_C(0x3fbc80276a9854d1);
    for (unsigned i = 0; i < sizeof flags / sizeof *flags; ++i) {
        struct { uint64_t left; int fd[2]; uint64_t right; } guarded = {
            before, {SENTINEL_LEFT, SENTINEL_RIGHT}, after
        };
        const uint64_t arguments[6] = {(uintptr_t)guarded.fd, poison | (uint32_t)flags[i]};
        uint64_t result[2];
        errno = EDOM;
        if (phase2_abi_probe_result((uintptr_t)pipe2, arguments, result))
            return 11;
        if (guarded.left != before || guarded.right != after)
            return 12;
        if (flags[i] < 0) {
            if ((uint32_t)result[0] != UINT32_MAX || errno != EINVAL ||
                guarded.fd[0] != SENTINEL_LEFT || guarded.fd[1] != SENTINEL_RIGHT)
                return 13;
            continue;
        }
        if ((uint32_t)result[0] || errno != EDOM || guarded.fd[0] < 0 || guarded.fd[1] < 0)
            return 14;
        struct endpoint_observation actual = endpoints(guarded.fd);
        unsigned expected = (flags[i] & O_CLOEXEC ? 3u : 0u) | (flags[i] & O_NONBLOCK ? 12u : 0u);
        if (actual.order != 7 || actual.flags != expected)
            return 15;
        if (raw_close(guarded.fd[0]) || raw_close(guarded.fd[1]))
            return 90;
    }
    return 0;
}
