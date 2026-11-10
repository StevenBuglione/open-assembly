#include "fixture.h"

extern unsigned phase2_abi_probe_result(uintptr_t, const uint64_t[6], uint64_t[2]);

static uint64_t poisoned(int value)
{
    return UINT64_C(0xb649f78d00000000) | (uint32_t)value;
}

static int verify(enum operation operation, int fd, const char *path, int flags,
                  int expected_errno, const struct kernel_stat *raw)
{
    struct stat_box box;
    set_bytes(&box, sizeof box, 0xa5);
    uintptr_t function;
    uint64_t args[6] = {(uintptr_t)path, (uintptr_t)&box.value, UINT64_C(0x346df7ab9a873ed2),
                       UINT64_C(0xbea2c714a7369733), UINT64_C(0x74523efab97243b2),
                       UINT64_C(0x2da97ea344ed31ac)};
    if (operation == FSTAT) {
        function = (uintptr_t)fstat;
        args[0] = poisoned(fd);
    } else if (operation == FSTATAT) {
        function = (uintptr_t)fstatat;
        args[0] = poisoned(fd);
        args[1] = (uintptr_t)path;
        args[2] = (uintptr_t)&box.value;
        args[3] = poisoned(flags);
    } else {
        function = operation == STAT ? (uintptr_t)stat : (uintptr_t)lstat;
    }
    uint64_t result[2] = {UINT64_MAX, UINT64_MAX};
    errno = TEST_ERRNO;
    if (phase2_abi_probe_result(function, args, result))
        return 11;
    if ((uint32_t)result[0] != (raw ? 0 : UINT32_MAX) || errno != expected_errno)
        return 12;
    if (raw) {
        if (!edges(&box) || !padding(&box) || !exact_fields(&box.value, raw))
            return 13;
    } else if (!all_bytes(&box, sizeof box, 0xa5)) {
        return 14;
    }
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    enum operation operation = operation_from(argv[1]);
    if (operation == BAD_OPERATION)
        return 90;
    int directory = (int)raw_open(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0);
    int file = (int)raw_open(AT_FDCWD, "abi-file", O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC, 0600);
    if (directory < 0 || file < 0 || raw_write(file, "abi", 3) != 3 ||
        !symlink_at("abi-file", directory, "abi-link"))
        return 91;
    struct kernel_stat expected;
    int fd = operation == FSTAT ? file : directory;
    int flags = operation == FSTATAT ? AT_SYMLINK_NOFOLLOW : 0;
    long observed = operation == FSTAT ? raw_fstat(file, &expected) :
                    raw_stat(directory, "abi-link",
                             operation == LSTAT || operation == FSTATAT ? K_AT_SYMLINK_NOFOLLOW : 0,
                             &expected);
    int result = observed ? 92 : verify(operation, fd, "abi-link", flags, TEST_ERRNO, &expected);
    if (!result && operation == FSTATAT) {
        if (raw_stat(AT_FDCWD, "abi-link", 0, &expected))
            result = 92;
        else
            result = verify(operation, AT_FDCWD, "abi-link", 0, TEST_ERRNO, &expected);
        if (!result)
            result = verify(operation, directory, "abi-link", 0x40000000, EINVAL, NULL);
    }
    if (!result)
        result = verify(operation, -1, "abi-missing", 0,
                        operation == FSTAT || operation == FSTATAT ? EBADF : ENOENT, NULL);

    int cleaned = raw_close(file) == 0;
    cleaned &= raw_close(directory) == 0;
    cleaned &= raw_unlink("abi-link", 0) == 0;
    cleaned &= raw_unlink("abi-file", 0) == 0;
    return cleaned ? result : 93;
}
