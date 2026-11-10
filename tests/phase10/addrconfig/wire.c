#include <errno.h>
#include <stdint.h>
#include <unistd.h>

extern long __al_syscall(long, long, long, long, long, long, long);
extern int __al_gai_addrconfig_parse(const unsigned char *, size_t, unsigned int *);

struct request { uint32_t length, mask; };
struct result { int32_t status; uint32_t mask; };
_Static_assert(sizeof(struct request) == 8 && sizeof(struct result) == 8, "LP64 wire protocol");

enum { PAGE = 4096, REGION = 9 * PAGE, MAP_SIZE = REGION + 2 * PAGE };

static int transfer(void *memory, size_t length, int writing)
{
    size_t done = 0;
    while (done < length) {
        unsigned char *cursor = (unsigned char *)memory + done;
        ssize_t count = writing ? write(STDOUT_FILENO, cursor, length - done) :
                                  read(STDIN_FILENO, cursor, length - done);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            return count == 0 && !done && !writing ? 0 : -1;
        done += (size_t)count;
    }
    return 1;
}

int main(int argc, char **argv)
{
    if (argc != 2 || (argv[1][0] != 'l' && argv[1][0] != 'r'))
        return 90;
    long map = __al_syscall(9, 0, MAP_SIZE, 0, 0x22, -1, 0);
    if (map < 0)
        return 91;
    unsigned char *buffer = (unsigned char *)(map + PAGE);
    struct request input;
    int read_status;
    while ((read_status = transfer(&input, sizeof input, 0)) == 1) {
        if (input.length > REGION || input.mask > 3 || __al_syscall(10, (long)buffer, REGION, 3, 0, 0, 0))
            return 92;
        unsigned char *bytes = argv[1][0] == 'l' ? buffer : buffer + REGION - input.length;
        if (transfer(bytes, input.length, 0) != 1 || __al_syscall(10, (long)buffer, REGION, 1, 0, 0, 0))
            return 93;
        unsigned int mask = input.mask;
        errno = EDOM;
        int status = __al_gai_addrconfig_parse(bytes, input.length, &mask);
        if (errno != EDOM)
            return 11;
        struct result result = {status, mask};
        if (transfer(&result, sizeof result, 1) != 1)
            return 94;
    }
    return read_status < 0 || __al_syscall(11, map, MAP_SIZE, 0, 0, 0, 0) ? 95 : 0;
}
