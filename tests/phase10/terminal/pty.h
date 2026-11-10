#ifndef OA_TEST_TERMINAL_PTY_H
#define OA_TEST_TERMINAL_PTY_H

#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

#ifdef OA_PHASE10_HOST
#include <sys/syscall.h>
#else
extern long __al_syscall(long, long, long, long, long, long, long);
#endif

enum {
    LINUX_TCGETS = 0x5401, LINUX_TCSETS = 0x5402, LINUX_TCSETSW = 0x5403,
    LINUX_TCSETSF = 0x5404, LINUX_TCSBRK = 0x5409, LINUX_TCXONC = 0x540a,
    LINUX_TCFLSH = 0x540b, LINUX_TIOCSCTTY = 0x540e, LINUX_TCSBRKP = 0x5425,
    LINUX_TIOCGSID = 0x5429, LINUX_TIOCGPTN = 0x80045430u, LINUX_TIOCSPTLCK = 0x40045431u,
};

struct linux_termios {
    unsigned int iflag, oflag, cflag, lflag;
    unsigned char line, cc[19];
};

static long raw_ioctl(int fd, unsigned int request, long argument)
{
#ifdef OA_PHASE10_HOST
    return syscall(SYS_ioctl, fd, (unsigned long)request, argument);
#else
    return __al_syscall(16, fd, request, argument, 0, 0, 0);
#endif
}

static int pty_open(char path[32])
{
    int master = open("/dev/ptmx", O_RDWR | O_NOCTTY);
    if (master < 0)
        return -1;
    int unlocked = 0;
    unsigned int index = 0;
    if (raw_ioctl(master, LINUX_TIOCSPTLCK, (long)&unlocked) ||
        raw_ioctl(master, LINUX_TIOCGPTN, (long)&index) ||
        snprintf(path, 32, "/dev/pts/%u", index) <= 0) {
        close(master);
        return -1;
    }
    return master;
}

#endif
