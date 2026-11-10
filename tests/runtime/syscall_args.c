#include <errno.h>
#include <linux/memfd.h>
#include <linux/mman.h>

#include "linux_abi.h"

int main(void)
{
    enum { PAGE = 4096 };
    static const char first[] = "first page";
    static const char second[] = "second page";
    errno = 903;
    long fd = __al_syscall(__NR_memfd_create, (long)"syscall-args", MFD_CLOEXEC, 0, 0, 0, 0);
    if (fd < 0)
        return 20;
    if (__al_syscall(__NR_ftruncate, fd, PAGE * 2, 0, 0, 0, 0) != 0)
        return 21;
    if (__al_syscall(__NR_pwrite64, fd, (long)first, sizeof first, 0, 0, 0) != sizeof first
            || __al_syscall(__NR_pwrite64, fd, (long)second, sizeof second, PAGE, 0, 0) != sizeof second)
        return 22;

    /* Unlike an anonymous mapping, this also makes the fd and offset observable. */
    long mapping = __al_syscall(__NR_mmap, 0, PAGE, PROT_READ, MAP_PRIVATE, fd, PAGE);
    if ((unsigned long)mapping >= (unsigned long)-4095)
        return 23;
    const char *bytes = (const char *)mapping;
    for (unsigned int i = 0; i < sizeof second; ++i)
        if (bytes[i] != second[i])
            return 24;
    if (__al_syscall(__NR_munmap, mapping, PAGE, 0, 0, 0, 0) != 0)
        return 25;

    if (__al_syscall(__NR_close, fd, 0, 0, 0, 0, 0) != 0)
        return 26;
    if (__al_syscall(__NR_close, fd, 0, 0, 0, 0, 0) != -EBADF || errno != 903)
        return 27;
    return 0;
}
