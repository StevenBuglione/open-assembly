#define _GNU_SOURCE
#include "pty.h"

#include <errno.h>
#include <stddef.h>
#include <string.h>
#include <termios.h>

#ifndef OA_PHASE10_HOST
_Static_assert(sizeof(struct termios) == 36 && _Alignof(struct termios) == 4 &&
               offsetof(struct termios, c_line) == 16 && offsetof(struct termios, c_cc) == 17,
               "Linux x86-64 termios layout");
#endif

static int attributes(int change)
{
    char path[32];
    int master = pty_open(path);
    if (master < 0)
        return 90;
    int slave = open(path, O_RDWR | O_NOCTTY);
    if (slave < 0)
        return 91;
    struct linux_termios before = {0}, after = {0};
    struct termios attr = {0};
    if (raw_ioctl(slave, LINUX_TCGETS, (long)&before))
        return 92;
    attr.c_lflag = (before.lflag ^ 8u) & 8u;
    errno = EDOM;
    if (tcgetattr(slave, &attr) || (attr.c_lflag & ECHO) != (before.lflag & 8u) ||
        errno != EDOM)
        return 11;
#ifndef OA_PHASE10_HOST
    if (memcmp(&attr, &before, sizeof before))
        return 12;
#endif
    if (change) {
        const struct termios original = attr;
        const int actions[] = {TCSANOW, TCSADRAIN, TCSAFLUSH};
        attr.c_lflag ^= ECHO;
        for (size_t i = 0; i < sizeof actions / sizeof actions[0]; ++i) {
            if (tcsetattr(slave, actions[i], &attr) || errno != EDOM ||
                raw_ioctl(slave, LINUX_TCGETS, (long)&after) ||
                (after.lflag & 8u) != ((before.lflag ^ 8u) & 8u))
                return 13;
            if (tcsetattr(slave, actions[i], &original) || errno != EDOM ||
                raw_ioctl(slave, LINUX_TCGETS, (long)&after) || (after.lflag & 8u) != (before.lflag & 8u))
                return 14;
        }
    }
    return close(slave) == 0 && close(master) == 0 ? 0 : 93;
}

static int speed(const char *mode)
{
    struct termios attr = {0};
    errno = EDOM;
    if (!strcmp(mode, "cfgetispeed")) {
        if (cfsetispeed(&attr, B9600))
            return 90;
        return cfgetispeed(&attr) == B9600 && errno == EDOM ? 0 : 21;
    }
    if (!strcmp(mode, "cfgetospeed")) {
        if (cfsetospeed(&attr, B9600))
            return 90;
        return cfgetospeed(&attr) == B9600 && errno == EDOM ? 0 : 22;
    }
    if (!strcmp(mode, "cfsetispeed"))
        return cfsetispeed(&attr, B9600) == 0 && cfgetispeed(&attr) == B9600 && errno == EDOM ? 0 : 23;
    if (!strcmp(mode, "cfsetospeed"))
        return cfsetospeed(&attr, B9600) == 0 && cfgetospeed(&attr) == B9600 && errno == EDOM ? 0 : 24;
    return 91;
}

#ifndef OA_PHASE10_HOST
static int encoding(void)
{
    struct termios attr = {0};
    attr.c_cflag = 0x82808200u;
    const tcflag_t baud = 0x100fu, input_baud = baud << 16;
    const tcflag_t original = attr.c_cflag;
    const speed_t rates[] = {B50, B4800, B9600, B38400, B115200, B1000000, B4000000};
    errno = EDOM;
    for (size_t i = 0; i < sizeof rates / sizeof rates[0]; ++i) {
        if (cfsetospeed(&attr, rates[i]) || cfgetospeed(&attr) != rates[i] ||
            cfgetispeed(&attr) != rates[i] || (attr.c_cflag & baud) != rates[i] ||
            (attr.c_cflag & ~(baud | input_baud)) != original || errno != EDOM)
            return 31;
        const speed_t next = rates[(i + 1) % (sizeof rates / sizeof rates[0])];
        if (cfsetispeed(&attr, next) || cfgetispeed(&attr) != next ||
            cfgetospeed(&attr) != rates[i] || ((attr.c_cflag & input_baud) >> 16) != next ||
            (attr.c_cflag & ~(baud | input_baud)) != original || errno != EDOM)
            return 32;
        if (cfsetispeed(&attr, B0) || cfgetispeed(&attr) != rates[i] ||
            (attr.c_cflag & input_baud) || errno != EDOM)
            return 33;
    }
    if (cfsetospeed(&attr, B0) || cfgetospeed(&attr) != B0 || cfgetispeed(&attr) != B0 ||
        attr.c_cflag != original || errno != EDOM)
        return 34;
    const struct termios saved = attr;
    if (cfsetispeed(&attr, (speed_t)0x1f01) != -1 || errno != EINVAL ||
        memcmp(&attr, &saved, sizeof attr))
        return 35;
    errno = EDOM;
    if (cfsetospeed(&attr, (speed_t)0x1f01) != -1 || errno != EINVAL ||
        memcmp(&attr, &saved, sizeof attr))
        return 36;
    return 0;
}
#endif

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "tcgetattr"))
        return attributes(0);
    if (!strcmp(argv[1], "tcsetattr"))
        return attributes(1);
#ifndef OA_PHASE10_HOST
    if (!strcmp(argv[1], "encoding"))
        return encoding();
#endif
    return speed(argv[1]);
}
