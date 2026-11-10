#define _GNU_SOURCE
#include "pty.h"

#include <errno.h>
#include <limits.h>
#include <string.h>
#include <sys/wait.h>
#include <termios.h>

static int exercise(int fd, const char *mode)
{
    errno = EDOM;
    if (!strcmp(mode, "tcdrain"))
        return tcdrain(fd) == 0 && errno == EDOM ? 0 : 11;
    if (!strcmp(mode, "tcflow"))
        return tcflow(fd, TCOOFF) == 0 && tcflow(fd, TCOON) == 0 && errno == EDOM ? 0 : 12;
    if (!strcmp(mode, "tcflush"))
        return tcflush(fd, TCIFLUSH) == 0 && tcflush(fd, TCOFLUSH) == 0 &&
               tcflush(fd, TCIOFLUSH) == 0 && errno == EDOM ? 0 : 13;
    if (!strcmp(mode, "tcsendbreak"))
        return tcsendbreak(fd, 0) == 0 && errno == EDOM ? 0 : 14;
    return 91;
}

static int pty_case(const char *mode)
{
    char path[32];
    int master = pty_open(path);
    if (master < 0)
        return 90;
    int slave = open(path, O_RDWR | O_NOCTTY);
    if (slave < 0)
        return 91;
    int result = exercise(slave, mode);
    if (close(slave) || close(master))
        return 93;
    return result;
}

static long new_session(void)
{
#ifdef OA_PHASE10_HOST
    return setsid();
#else
    return __al_syscall(112, 0, 0, 0, 0, 0, 0);
#endif
}

static int session(void)
{
    char path[32];
    int master = pty_open(path);
    if (master < 0)
        return 90;
    pid_t child = fork();
    if (child < 0)
        return 91;
    if (!child) {
        long sid = new_session();
        if (sid <= 0 || sid != getpid())
            _exit(94);
        int slave = open(path, O_RDWR | O_NOCTTY);
        if (slave < 0 || raw_ioctl(slave, LINUX_TIOCSCTTY, 0))
            _exit(95);
        int raw_session = -1;
        if (raw_ioctl(slave, LINUX_TIOCGSID, (long)&raw_session) || raw_session != sid)
            _exit(96);
        errno = EDOM;
        int valid = tcgetsid(slave) == sid && errno == EDOM;
        _exit(valid && close(slave) == 0 ? 0 : 15);
    }
    int status = 0;
    if (waitpid(child, &status, 0) != child || close(master) || !WIFEXITED(status))
        return 92;
    return WEXITSTATUS(status);
}

static int rejected(const char *mode)
{
    errno = EDOM;
    if (!strcmp(mode, "reject-drain"))
        return tcdrain(-1) == -1 && errno == EBADF ? 0 : 31;
    if (!strcmp(mode, "reject-flow"))
        return tcflow(-1, TCOON) == -1 && errno == EBADF ? 0 : 32;
    if (!strcmp(mode, "reject-flush"))
        return tcflush(-1, TCIOFLUSH) == -1 && errno == EBADF ? 0 : 33;
    if (!strcmp(mode, "reject-break"))
        return tcsendbreak(-1, 0) == -1 && errno == EBADF ? 0 : 34;
    return 91;
}

static int errors(void)
{
    int fd = open("/dev/null", O_RDONLY);
    if (fd < 0)
        return 90;
    struct termios value = {0};
    errno = EDOM;
    if (tcgetattr(fd, &value) != -1 || errno != ENOTTY ||
        tcsetattr(fd, TCSANOW, &value) != -1 || errno != ENOTTY ||
        tcdrain(fd) != -1 || errno != ENOTTY ||
        tcflow(fd, TCOON) != -1 || errno != ENOTTY ||
        tcflush(fd, TCIOFLUSH) != -1 || errno != ENOTTY ||
        tcsendbreak(fd, 0) != -1 || errno != ENOTTY ||
        tcgetsid(fd) != -1 || errno != ENOTTY)
        return 20;
    if (tcgetattr(-1, &value) != -1 || errno != EBADF ||
        tcsetattr(-1, TCSANOW, &value) != -1 || errno != EBADF ||
        tcdrain(-1) != -1 || errno != EBADF ||
        tcflow(-1, TCOON) != -1 || errno != EBADF ||
        tcflush(-1, TCIOFLUSH) != -1 || errno != EBADF ||
        tcsendbreak(-1, 0) != -1 || errno != EBADF ||
        tcgetsid(-1) != -1 || errno != EBADF)
        return 21;
    return close(fd) == 0 ? 0 : 93;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "tcgetsid"))
        return session();
    if (!strcmp(argv[1], "errors"))
        return errors();
    if (!strncmp(argv[1], "reject-", 7))
        return rejected(argv[1]);
    return pty_case(argv[1]);
}
