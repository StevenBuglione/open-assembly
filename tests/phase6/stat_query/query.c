#include "contract.h"

extern long __real___al_syscall(long, long, long, long, long, long, long);
extern unsigned phase2_abi_probe_result(uintptr_t, const uint64_t[6], uint64_t[2]);

struct request {
    int selector;
    long descriptor;
    const char *path;
    long flags;
    unsigned expected_calls;
    int denied;
};

static struct request watched;
static struct stat *public_result;
static unsigned armed, calls;

long __wrap___al_syscall(long nr, long a1, long a2, long a3, long a4, long a5, long a6)
{
    if (!armed)
        return __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
    if (++calls > watched.expected_calls)
        _exit(14);
    if (nr != watched.selector || a1 != watched.descriptor ||
        (nr == QUERY_FSTATAT && (a2 != (long)watched.path || a4 != watched.flags)))
        _exit(15);
    uintptr_t scratch = (uintptr_t)(nr == QUERY_FSTAT ? a2 : a3);
    uintptr_t output = (uintptr_t)public_result;
    uintptr_t distance = scratch >= output ? scratch - output : output - scratch;
    if (!scratch || distance < sizeof(struct stat))
        _exit(16);
    if (watched.denied)
        return -4095;

    long status = __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
    if (!status) {
        /* Exercise the documented publication rule for reserved raw bytes. */
        unsigned char *raw = (unsigned char *)scratch;
        set_bytes(raw + 36, 4, 0xd1);
        set_bytes(raw + 120, 24, 0xe2);
    }
    return status;
}

static int probe(struct request request, const struct kernel_stat *expected,
                 int expected_errno, int null_result, int abi)
{
    struct stat_box box;
    set_bytes(&box, sizeof box, 0xa5);
    watched = request;
    public_result = null_result ? NULL : &box.value;
    calls = 0;
    errno = TEST_ERRNO;
    armed = 1;
    uint64_t result;
    unsigned changed = 0;
    if (abi) {
        const uint64_t args[6] = {
            UINT64_C(0xc03ba61700000000) | (uint32_t)request.selector,
            (uint64_t)request.descriptor, (uintptr_t)request.path, (uint64_t)request.flags,
            (uintptr_t)public_result, UINT64_C(0x54ac3958ed14f76b)
        };
        uint64_t returns[2] = {UINT64_MAX, UINT64_MAX};
        changed = phase2_abi_probe_result((uintptr_t)__al_stat_query, args, returns);
        result = returns[0];
    } else {
        result = (uint64_t)__al_stat_query(request.selector, request.descriptor, request.path,
                                           request.flags, public_result);
    }
    int error = errno;
    armed = 0;
    if (changed)
        return 17;
    if (calls != request.expected_calls)
        return 14;
    if (result != (expected ? 0 : UINT64_MAX) || error != expected_errno)
        return 11;
    if (!expected)
        return all_bytes(&box, sizeof box, 0xa5) ? 0 : 13;
    if (!edges(&box))
        return 13;
    return exact_fields(&box.value, expected) && padding(&box) ? 0 : 12;
}

static int sequence(int dir, int file, int abi)
{
    struct kernel_stat regular, symbolic, unused;
    if (raw_fstat(file, &regular) ||
        raw_stat(dir, "link", K_AT_SYMLINK_NOFOLLOW, &symbolic) ||
        raw_fstat(-1, &unused) != -EBADF ||
        raw_stat(dir, "absent", 0, &unused) != -ENOENT ||
        raw_stat(dir, "file", 0x40000000, &unused) != -EINVAL)
        return 92;
    if (regular.size != (1L << 32) + 17 || (regular.mode & 0170000) != 0100000 ||
        symbolic.size != 4 || (symbolic.mode & 0170000) != 0120000)
        return 92;

    const struct {
        struct request request;
        const struct kernel_stat *expected;
        int error, null_result;
    } cases[] = {
        {{QUERY_FSTAT, file, "ignored", 0x40000000, 1, 0}, &regular, TEST_ERRNO, 0},
        {{QUERY_FSTATAT, dir, "link", AT_SYMLINK_NOFOLLOW, 1, 0}, &symbolic, TEST_ERRNO, 0},
        {{QUERY_FSTATAT, dir, "link", 0, 1, 0}, &regular, TEST_ERRNO, 0},
        {{QUERY_FSTATAT, AT_FDCWD, "stat-query-dir/file", 0, 1, 0}, &regular, TEST_ERRNO, 0},
        {{QUERY_FSTAT, -1, NULL, 0, 1, 0}, NULL, EBADF, 0},
        {{QUERY_FSTATAT, dir, "absent", 0, 1, 0}, NULL, ENOENT, 0},
        {{QUERY_FSTATAT, dir, "file", 0x40000000, 1, 0}, NULL, EINVAL, 0},
        {{QUERY_FSTAT, file, NULL, 0, 1, 1}, NULL, 4095, 0},
        {{QUERY_FSTAT, file, NULL, 0, 0, 0}, NULL, EFAULT, 1},
        {{-99, file, NULL, 0, 0, 0}, NULL, EINVAL, 0},
        {{-99, file, NULL, 0, 0, 0}, NULL, EFAULT, 1},
    };
    for (size_t i = 0; i < sizeof cases / sizeof *cases; ++i) {
        int result = probe(cases[i].request, cases[i].expected, cases[i].error,
                           cases[i].null_result, abi);
        if (result)
            return result;
    }
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2 || (!same_text(argv[1], "unit") && !same_text(argv[1], "abi")))
        return 90;
    if (raw_mkdir("stat-query-dir", 0700))
        return 91;
    int dir = (int)raw_open(AT_FDCWD, "stat-query-dir", O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0);
    int file = (int)raw_open(dir, "file", O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC, 0641);
    const long times[4] = {-123, 784123456, (1L << 32) + 5, 210987654};
    if (dir < 0 || file < 0 ||
        kernel_call(__NR_ftruncate, file, (1L << 32) + 17, 0, 0, 0, 0) ||
        kernel_call(__NR_utimensat, dir, (long)"file", (long)times, 0, 0, 0) ||
        !symlink_at("file", dir, "link"))
        return 91;
    int result = sequence(dir, file, same_text(argv[1], "abi"));
    int cleaned = raw_close(file) == 0;
    cleaned &= raw_close(dir) == 0;
    cleaned &= raw_unlink("stat-query-dir/link", 0) == 0;
    cleaned &= raw_unlink("stat-query-dir/file", 0) == 0;
    cleaned &= raw_unlink("stat-query-dir", K_AT_REMOVEDIR) == 0;
    return cleaned ? result : 93;
}
