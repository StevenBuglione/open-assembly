#include "fixture.h"

extern long __real___al_syscall(long, long, long, long, long, long, long);

enum scenario { NORMAL, REAL_APPEND, GETFL_ERROR, STATFS_ERROR, OVERLAY, NO_SYSCALL, NEGATIVE, ZERO };
static enum scenario mode;
static int armed, watched;
static unsigned flags_calls, type_calls, ordinary_calls, append_calls;

long __wrap___al_syscall(long number, long fd, long a2, long a3, long a4, long a5, long a6)
{
    if (armed && fd == watched) {
        if (number == __NR_fcntl && a2 == K_F_GETFL) {
            ++flags_calls;
            if (mode == GETFL_ERROR)
                return -4095;
        }
        if (number == K_FSTATFS) {
            ++type_calls;
            if (mode == STATFS_ERROR) {
                *(long *)(uintptr_t)a2 = 0x01021994;
                return -4095;
            }
            if (mode == OVERLAY) {
                long result = __real___al_syscall(number, fd, a2, a3, a4, a5, a6);
                if (result >= 0)
                    *(long *)(uintptr_t)a2 = 0x794c7630;
                return result;
            }
        }
        if (number == K_PWRITE)
            ++ordinary_calls;
        if (number == K_PWRITEV2) {
            ++append_calls;
            if (mode == NO_SYSCALL)
                return -ENOSYS;
        }
    }
    return __real___al_syscall(number, fd, a2, a3, a4, a5, a6);
}

static int setup(int append)
{
    int fd = memory_file();
    if (fd < 0 || raw_write(fd, "abc", 3) != 3 || raw_seek(fd, 2, SEEK_SET) != 2 ||
        (append && raw_fcntl(fd, K_F_SETFL, O_APPEND)))
        return -1;
    return fd;
}

static int exact_file(int fd, int updated)
{
    char bytes[5];
    return raw_pread(fd, bytes, sizeof bytes, 0) == 3 && bytes[0] == 'a' &&
           bytes[1] == (updated ? 'Z' : 'b') && bytes[2] == 'c' &&
           raw_seek(fd, 0, SEEK_CUR) == 2;
}

static int append_available(void)
{
    int fd = setup(1);
    if (fd < 0)
        return -1;
    char value = 'Z';
    struct { void *base; size_t size; } item = {&value, 1};
    long result = kernel_call(K_PWRITEV2, fd, (long)&item, 1, 1, 0, K_RWF_NOAPPEND);
    int supported = result == 1;
    int valid = (supported || result == -EOPNOTSUPP || result == -ENOSYS) && exact_file(fd, supported);
    return raw_close(fd) || !valid ? -1 : supported;
}

static int exercise(enum scenario selected, int supported)
{
    int append = selected != NORMAL && selected != NEGATIVE;
    int fd = setup(append);
    if (fd < 0)
        return 90;
    mode = selected;
    watched = fd;
    flags_calls = type_calls = ordinary_calls = append_calls = 0;
    armed = 1;
    errno = TEST_ERRNO;
    long result = pwrite(fd, "Z", selected == NEGATIVE || selected == ZERO ? 0 : 1,
                         selected == NEGATIVE ? -1 : 1);
    int observed_error = errno;
    armed = 0;

    int update = selected == NORMAL || (selected == REAL_APPEND && supported);
    long expected = selected == ZERO ? 0 : update ? 1 : -1;
    int error = expected >= 0 ? TEST_ERRNO : selected == NEGATIVE ? EINVAL :
                selected == GETFL_ERROR || selected == STATFS_ERROR ? 4095 : EOPNOTSUPP;
    if (result != expected || observed_error != error || !exact_file(fd, update))
        return 11 + (int)selected;
    if (selected == GETFL_ERROR &&
        (flags_calls != 1 || type_calls || ordinary_calls || append_calls))
        return 21;
    if ((selected == STATFS_ERROR || selected == OVERLAY) &&
        (flags_calls != 1 || type_calls != 1 || ordinary_calls || append_calls))
        return 22;
    if (selected == NO_SYSCALL &&
        (flags_calls != 1 || type_calls != 1 || ordinary_calls || append_calls != 1))
        return 23;
    if (raw_close(fd))
        return 91;
    return 0;
}

int main(void)
{
    int supported = append_available();
    if (supported < 0)
        return 92;
    for (enum scenario current = NORMAL; current <= ZERO; ++current) {
        int status = exercise(current, supported);
        if (status)
            return status;
    }
    errno = TEST_ERRNO;
    return pwrite(-1, "Z", 1, 1) == -1 && errno == EBADF ? 0 : 24;
}
