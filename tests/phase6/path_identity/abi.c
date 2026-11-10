#include "../kernel_abi.h"

#include <stdint.h>

extern unsigned phase2_abi_probe_result(uintptr_t, const uint64_t[6], uint64_t[2]);

static int check_call(uintptr_t function, uint64_t arguments[6], uint64_t want,
                      int expected_errno, int int_result)
{
    uint64_t result[2] = {UINT64_MAX, UINT64_MAX};
    errno = TEST_ERRNO;
    if (phase2_abi_probe_result(function, arguments, result))
        return 11;
    if (int_result)
        result[0] = (uint32_t)result[0];
    return result[0] == want && errno == expected_errno ? 0 : 12;
}

static int cwd_abi(void)
{
    char expected[4096], actual[4097] = {0};
    long length = kernel_call(__NR_getcwd, (long)expected, sizeof expected, 0, 0, 0, 0);
    if (length < 2 || length > (long)sizeof expected)
        return 90;
    actual[0] = '!';
    actual[length] = '!';
    uint64_t args[6] = {(uintptr_t)actual, (uint64_t)length};
    int status = check_call((uintptr_t)getcwd, args, (uintptr_t)actual, TEST_ERRNO, 0);
    if (status)
        return status;
    if (actual[length - 1] || actual[length] != '!' || !same_text(actual, expected))
        return 13;
    args[1] = (uint64_t)length - 1;
    return check_call((uintptr_t)getcwd, args, 0, ERANGE, 0);
}

static int link_abi(void)
{
    if (kernel_call(__NR_symlinkat, (long)"abc", AT_FDCWD, (long)"abi-link", 0, 0, 0))
        return 90;
    char actual[] = {'L', '1', '2', '3', 'R'};
    uint64_t args[6] = {(uintptr_t)"abi-link", (uintptr_t)(actual + 1), 3};
    int status = check_call((uintptr_t)readlink, args, 3, TEST_ERRNO, 0);
    if (status)
        return status;
    if (actual[0] != 'L' || actual[1] != 'a' || actual[2] != 'b' ||
        actual[3] != 'c' || actual[4] != 'R')
        return 13;
    if (raw_unlink("abi-link", 0))
        return 91;
    return check_call((uintptr_t)readlink, args, UINT64_MAX, ENOENT, 0);
}

static int remove_abi(int directory)
{
    const char *path = "abi-entry";
    if (directory) {
        if (raw_mkdir(path, 0700))
            return 90;
    } else {
        int fd = (int)raw_open(AT_FDCWD, path, O_CREAT | O_EXCL | O_WRONLY, 0600);
        if (fd < 0 || raw_close(fd))
            return 90;
    }
    uintptr_t function = directory ? (uintptr_t)rmdir : (uintptr_t)unlink;
    uint64_t args[6] = {(uintptr_t)path};
    int status = check_call(function, args, 0, TEST_ERRNO, 1);
    if (status)
        return status;
    struct kernel_stat stat;
    if (raw_stat(AT_FDCWD, path, K_AT_SYMLINK_NOFOLLOW, &stat) != -ENOENT)
        return 13;
    return check_call(function, args, UINT32_MAX, ENOENT, 1);
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (same_text(argv[1], "getcwd"))
        return cwd_abi();
    if (same_text(argv[1], "readlink"))
        return link_abi();
    if (same_text(argv[1], "unlink"))
        return remove_abi(0);
    if (same_text(argv[1], "rmdir"))
        return remove_abi(1);
    return 90;
}
