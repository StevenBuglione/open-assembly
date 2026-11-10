#include "fixture.h"

extern unsigned phase2_abi_probe_result(uintptr_t, const uint64_t[6], uint64_t[2]);

static int failure(enum operation operation, const char *path, int expected_errno)
{
    char zero[] = "exec-abi-name", token[] = "two words";
    char item[] = "OA_TEST=explicit";
    char *argv[] = {zero, token, NULL};
    char *env[] = {item, NULL};
    uintptr_t function = operation == EXECVE ? (uintptr_t)execve :
                         operation == EXECV ? (uintptr_t)execv : (uintptr_t)execvp;
    uint64_t arguments[6] = {
        (uintptr_t)path, (uintptr_t)argv, UINT64_C(0x8aedc672122fd457),
        UINT64_C(0xad2f604f02bced34), UINT64_C(0x391afda23c7054e3),
        UINT64_C(0xbf82904a6fe3ac29)
    };
    if (operation == EXECVE)
        arguments[2] = (uintptr_t)env;
    long pid = identity();
    uint64_t result[2] = {UINT64_MAX, UINT64_MAX};
    errno = TEST_ERRNO;
    if (phase2_abi_probe_result(function, arguments, result))
        return 11;
    if ((uint32_t)result[0] != UINT32_MAX || errno != expected_errno)
        return 12;
    if (identity() != pid || argv[0] != zero || argv[1] != token || argv[2] ||
        env[0] != item || env[1] || !same_text(zero, "exec-abi-name") ||
        !same_text(token, "two words") || !same_text(item, "OA_TEST=explicit"))
        return 13;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    enum operation operation = operation_from(argv[1]);
    if (operation == BAD_OPERATION)
        return 90;
    if (!make_file("abi-file", "plain\n", 6, 0600))
        return 91;
    char path[] = "PATH=absent:.", value[] = "OA_TEST=ambient";
    char *active[] = {path, value, NULL};
    char **original = environ;
    environ = active;
    int status = failure(operation, "abi-missing", ENOENT);
    if (!status)
        status = failure(operation, operation == EXECVP ? "abi-file" : "abi-file/child",
                         operation == EXECVP ? EACCES : ENOTDIR);
    if (!status && (environ != active || active[0] != path || active[1] != value || active[2]))
        status = 13;
    environ = original;
    return raw_unlink("abi-file", 0) ? 92 : status;
}
