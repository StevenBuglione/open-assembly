#include "../kernel_abi.h"
#include <stdint.h>
#include <sys/stat.h>

extern int probe_open(const char *path, int flags, ...);
extern int probe_openat(int dirfd, const char *path, int flags, ...);
extern unsigned phase2_abi_probe_result(uintptr_t target, const uint64_t arguments[6],
                                        uint64_t result[2]);

static int call_abi(int at, int directory, const char *path, int flags, mode_t mode,
                    int expected_errno, int *descriptor)
{
    const uint64_t poisoned_dir = UINT64_C(0xc0357d5200000000) | (uint32_t)directory;
    const uint64_t poisoned_flags = UINT64_C(0x897fd4a700000000) | (uint32_t)flags;
    const uint64_t poisoned_mode = UINT64_C(0x1e98c05200000000) | (uint32_t)mode;
    uint64_t arguments[6] = {poisoned_dir, (uintptr_t)path, poisoned_flags, poisoned_mode};
    uintptr_t target = (uintptr_t)probe_openat;
    if (!at) {
        arguments[0] = (uintptr_t)path;
        arguments[1] = poisoned_flags;
        arguments[2] = poisoned_mode;
        target = (uintptr_t)probe_open;
    }
    uint64_t result[2];
    errno = TEST_ERRNO;
    if (phase2_abi_probe_result(target, arguments, result) || errno != expected_errno)
        return 0;
    *descriptor = (int32_t)(uint32_t)result[0];
    return 1;
}

static int matches(int descriptor, unsigned expected_mode, unsigned expected_links)
{
    struct kernel_stat info;
    return descriptor >= 0 && raw_fstat(descriptor, &info) == 0 &&
           (info.mode & 0177777u) == (0100000u | expected_mode) && info.links == expected_links &&
           raw_fcntl(descriptor, K_F_GETFD, 0) == K_FD_CLOEXEC;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    int at = same_text(argv[1], "openat");
    if (!at && !same_text(argv[1], "open"))
        return 91;
    long cwd = raw_open(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY, 0);
    long temporary = raw_open(AT_FDCWD, "/dev/shm", O_RDONLY | O_DIRECTORY, 0);
    long previous = kernel_call(__NR_umask, 0027, 0, 0, 0, 0, 0);
    if (cwd < 0 || temporary < 0 || previous < 0)
        return 92;

    int descriptor;
    if (!call_abi(at, (int)cwd, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0777,
                  TEST_ERRNO, &descriptor) ||
        descriptor < 0 || raw_fcntl(descriptor, K_F_GETFD, 0) != K_FD_CLOEXEC || raw_close(descriptor))
        return 11;

    static const char fresh[] = "open-abi-created";
    if (!call_abi(at, (int)cwd, fresh, O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC, 0677,
                  TEST_ERRNO, &descriptor) || !matches(descriptor, 0650, 1))
        return 12;
    if (raw_close(descriptor) || raw_unlink(fresh, 0))
        return 93;

    const char *tmp_path = at ? "." : "/dev/shm";
    int tmp_flags = O_TMPFILE | O_RDWR | O_CLOEXEC;
    long baseline = raw_open((int)temporary, ".", tmp_flags, 0666);
    if (!call_abi(at, (int)temporary, tmp_path, tmp_flags, 0666,
                  baseline < 0 ? (int)-baseline : TEST_ERRNO, &descriptor))
        return 13;
    if (baseline < 0) {
        if (descriptor != -1)
            return 14;
    } else if (!matches(descriptor, 0640, 0) || raw_close(descriptor) || raw_close((int)baseline)) {
        return 15;
    }

    if (!call_abi(at, -1, "open-abi-missing", O_RDONLY, 01777,
                  at ? EBADF : ENOENT, &descriptor) || descriptor != -1)
        return 16;
    if (raw_close((int)temporary) || raw_close((int)cwd) ||
        kernel_call(__NR_umask, previous, 0, 0, 0, 0, 0) != 0027)
        return 94;
    return 0;
}
