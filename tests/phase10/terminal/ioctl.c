#include <errno.h>
#include <limits.h>
#include <stddef.h>
#include <termios.h>

extern long __real___al_syscall(long, long, long, long, long, long, long);

enum {
    TCGETS = 0x5401, TCSETS = 0x5402, TCSETSW = 0x5403, TCSETSF = 0x5404,
    TCSBRK = 0x5409, TCXONC = 0x540a, TCFLSH = 0x540b, TCSBRKP = 0x5425, TIOCGSID = 0x5429,
};
static const long descriptor = -17;
static long request, argument, response;
static int active, calls, matched;
static struct termios value;

long __wrap___al_syscall(long nr, long a1, long a2, long a3, long a4, long a5, long a6)
{
    if (!active || nr != 16)
        return __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
    ++calls;
    matched = a1 == descriptor && a2 == request && !a4 && !a5 && !a6;
    if (request == TIOCGSID) {
        matched = matched && a3 != 0;
        if (matched && !response)
            *(int *)a3 = 0x12345678;
    } else {
        matched = matched && a3 == argument;
    }
    return response;
}

static void expect(long operation, long data, long result)
{
    request = operation;
    argument = data;
    response = result;
    calls = 0;
    matched = 0;
    errno = EDOM;
}

static int passed(void)
{
    return calls == 1 && matched && errno == (response ? -response : EDOM);
}

int main(void)
{
    active = 1;
    expect(TCGETS, (long)&value, -EIO);
    if (tcgetattr((int)descriptor, &value) != -1 || !passed())
        return 11;

    const int actions[] = {TCSANOW, TCSADRAIN, TCSAFLUSH};
    const long modes[] = {TCSETS, TCSETSW, TCSETSF};
    for (size_t i = 0; i < sizeof actions / sizeof actions[0]; ++i) {
        expect(modes[i], (long)&value, 0);
        if (tcsetattr((int)descriptor, actions[i], &value) || !passed())
            return 12;
    }
    expect(0, 0, 0);
    if (tcsetattr((int)descriptor, INT_MIN, &value) != -1 || errno != EINVAL || calls)
        return 13;

    expect(TCSBRK, 1, 0);
    if (tcdrain((int)descriptor) || !passed())
        return 14;
    const int flow[] = {TCOOFF, TCOON, TCIOFF, TCION};
    for (size_t i = 0; i < sizeof flow / sizeof flow[0]; ++i) {
        expect(TCXONC, (long)i, 0);
        if (tcflow((int)descriptor, flow[i]) || !passed())
            return 15;
    }
    expect(0, 0, 0);
    if (tcflow((int)descriptor, INT_MIN) != -1 || errno != EINVAL || calls)
        return 16;
    const int flush[] = {TCIFLUSH, TCOFLUSH, TCIOFLUSH};
    for (size_t i = 0; i < sizeof flush / sizeof flush[0]; ++i) {
        expect(TCFLSH, (long)i, 0);
        if (tcflush((int)descriptor, flush[i]) || !passed())
            return 17;
    }
    expect(0, 0, 0);
    if (tcflush((int)descriptor, INT_MIN) != -1 || errno != EINVAL || calls)
        return 18;

    const int durations[] = {INT_MIN, -1, 0, 1, INT_MAX / 100 - 1, INT_MAX / 100, INT_MAX};
    for (size_t i = 0; i < sizeof durations / sizeof durations[0]; ++i) {
        int duration = durations[i];
        long limited = duration > INT_MAX / 100 ? INT_MAX / 100 : duration;
        expect(duration > 0 ? TCSBRKP : TCSBRK, duration > 0 ? limited : 0, 0);
        if (tcsendbreak((int)descriptor, duration) || !passed())
            return 19;
    }
    expect(TIOCGSID, 0, 0);
    if (tcgetsid((int)descriptor) != 0x12345678 || !passed())
        return 20;
    expect(TIOCGSID, 0, -EIO);
    if (tcgetsid((int)descriptor) != -1 || !passed())
        return 21;
    active = 0;
    return 0;
}
