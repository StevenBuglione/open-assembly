#include "contract.h"

#include <linux/filter.h>
#include <linux/prctl.h>
#include <linux/seccomp.h>

static int installed(void)
{
    struct sock_filter instructions[] = {
        BPF_STMT(BPF_LD | BPF_W | BPF_ABS, offsetof(struct seccomp_data, nr)),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_fstat, 2, 0),
        BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, __NR_newfstatat, 2, 0),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | 4095),
        BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ERRNO | EACCES),
    };
    struct sock_fprog filter = {
        .len = sizeof instructions / sizeof *instructions, .filter = instructions,
    };
    return kernel_call(__NR_prctl, PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0, 0) == 0 &&
           kernel_call(__NR_seccomp, SECCOMP_SET_MODE_FILTER, 0, (long)&filter, 0, 0, 0) == 0 &&
           kernel_call(__NR_prctl, PR_GET_SECCOMP, 0, 0, 0, 0, 0) == SECCOMP_MODE_FILTER;
}

static int denied(int selector, long fd, const char *path, int expected)
{
    struct stat_box box;
    set_bytes(&box, sizeof box, 0xa5);
    errno = TEST_ERRNO;
    long result = __al_stat_query(selector, fd, path, 0, &box.value);
    if (result != -1 || errno != expected)
        return 41;
    return all_bytes(&box, sizeof box, 0xa5) ? 0 : 42;
}

int main(void)
{
    int fd = (int)raw_open(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0);
    struct kernel_stat raw;
    if (fd < 0 || raw_fstat(fd, &raw) || raw_stat(AT_FDCWD, ".", 0, &raw) || !installed())
        return 94;
    set_bytes(&raw, sizeof raw, 0xa5);
    if (raw_fstat(fd, &raw) != -4095 || !all_bytes(&raw, sizeof raw, 0xa5) ||
        raw_stat(AT_FDCWD, ".", 0, &raw) != -EACCES || !all_bytes(&raw, sizeof raw, 0xa5))
        return 94;
    int result = denied(QUERY_FSTAT, fd, NULL, 4095);
    if (!result)
        result = denied(QUERY_FSTATAT, AT_FDCWD, ".", EACCES);
    return raw_close(fd) ? 95 : result;
}
