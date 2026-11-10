#include "identity.h"

extern unsigned phase2_abi_probe_result(uintptr_t target, const uint64_t arguments[6],
                                        uint64_t result[2]);

static int probe(pid_t (*query)(void), int parent, long expected, int sentinel)
{
    if (expected < 0 || expected > INT32_MAX)
        return 90;
    static const uint64_t unused[6] = {
        UINT64_C(0xa2357ed86b3c4f11), UINT64_C(0x2f12d504638bdc95),
        UINT64_C(0x877fed4e48254043), UINT64_C(0x5f077ba175566430),
        UINT64_C(0xd61b7e79a82d051d), UINT64_C(0x82b0d98a41c954ac)
    };
    uint64_t result[2];
    errno = sentinel;
    if (phase2_abi_probe_result((uintptr_t)query, unused, result) || errno != sentinel)
        return 11;
    if ((uint32_t)result[0] != (uint32_t)expected || raw_identity(parent) != expected)
        return 12;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 91;
    int parent = same_text(argv[1], "getppid");
    if (!parent && !same_text(argv[1], "getpid"))
        return 92;
    pid_t (*query)(void) = parent ? getppid : getpid;
    long own = raw_identity(0);
    if (own <= 0)
        return 93;
    int current = probe(query, parent, parent ? raw_identity(1) : own, EDOM);
    if (current)
        return current;
    long child = raw_fork_process();
    if (child < 0)
        return 94;
    if (!child)
        _exit(probe(query, parent, parent ? own : raw_identity(0), 0x3071));
    int status = raw_wait_status(child);
    return status < 0 ? 95 : status;
}
