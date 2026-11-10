#include <errno.h>
#include <stdint.h>
#include <termios.h>

extern unsigned phase2_abi_probe(uintptr_t, const uint64_t[6]);

#define ADDRESS(value) ((uint64_t)(uintptr_t)(value))
#define INTARG(value) (UINT64_C(0xa135ef7000000000) | (uint32_t)(value))
#define CALL(function, ...) phase2_abi_probe((uintptr_t)function, (const uint64_t[6]){__VA_ARGS__})
#define ERROR(function, ...) do { \
    errno = EDOM; \
    if (CALL(function, __VA_ARGS__) || errno != EBADF) \
        return stage; \
    ++stage; \
} while (0)

int main(void)
{
    int stage = 10;
    const uint64_t bad = INTARG(-1);
    struct termios value = {0};
    ERROR(tcgetattr, bad, ADDRESS(&value));
    ERROR(tcsetattr, bad, INTARG(TCSANOW), ADDRESS(&value));
    ERROR(tcdrain, bad);
    ERROR(tcflow, bad, INTARG(TCOON));
    ERROR(tcflush, bad, INTARG(TCIOFLUSH));
    ERROR(tcsendbreak, bad, INTARG(-2));
    ERROR(tcgetsid, bad);

    errno = EDOM;
    if (CALL(cfsetispeed, ADDRESS(&value), INTARG(B115200)) ||
        cfgetispeed(&value) != B115200 || errno != EDOM)
        return 20;
    if (CALL(cfsetospeed, ADDRESS(&value), INTARG(B9600)) ||
        cfgetospeed(&value) != B9600 || errno != EDOM)
        return 21;
    if (CALL(cfgetispeed, ADDRESS(&value)) || CALL(cfgetospeed, ADDRESS(&value)) || errno != EDOM)
        return 22;
    return 0;
}
