#include "../kernel_abi.h"

#include <linux/filter.h>
#include <linux/prctl.h>
#include <linux/seccomp.h>

static int untouched(const char *buffer, size_t size)
{
    for (size_t i = 0; i < size; ++i)
        if (buffer[i] != '!')
            return 0;
    return 1;
}

int main(void)
{
    char buffer[4096];
    long initial = kernel_call(__NR_getcwd, (long)buffer, sizeof buffer, 0, 0, 0, 0);
    if (initial < 2 || initial > (long)sizeof buffer || buffer[0] != '/' || buffer[initial - 1])
        return 94;

    struct sock_filter instructions[] = {
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, nr)),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_getcwd, 1, 0),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | 4095),
    };
    struct sock_fprog filter = {
        .len = sizeof instructions / sizeof *instructions, .filter = instructions,
    };
    if (kernel_call(__NR_prctl, PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0, 0) ||
        kernel_call(__NR_seccomp, SECCOMP_SET_MODE_FILTER, 0, (long)&filter, 0, 0, 0) ||
        kernel_call(__NR_prctl, PR_GET_SECCOMP, 0, 0, 0, 0, 0) != SECCOMP_MODE_FILTER)
        return 94;
    for (size_t i = 0; i < sizeof buffer; ++i)
        buffer[i] = '!';
    if (kernel_call(__NR_getcwd, (long)buffer, sizeof buffer, 0, 0, 0, 0) != -4095 ||
        !untouched(buffer, sizeof buffer))
        return 94;
    errno = TEST_ERRNO;
    char *result = getcwd(buffer, sizeof buffer);
    return result || errno != 4095 || !untouched(buffer, sizeof buffer) ? 29 : 0;
}
