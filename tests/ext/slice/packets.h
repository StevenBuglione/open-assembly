#include <errno.h>
#include <slice.h>
#include <stdint.h>
#include <unistd.h>

struct request { uint64_t shape, extent, request, content; };
struct response { int64_t status; uint64_t first, second, output, error; };
_Static_assert(sizeof(struct request) == 32 && sizeof(struct response) == 40, "LP64 packet ABI");

enum { EMPTY = 1, BAD_BASE = 2, WRAP = 3, NO_OUTPUT = 4, NO_CURSOR = 5, NO_LENGTH = 6 };

static void observe(const struct request *, struct response *);

int main(void)
{
    for (;;) {
        struct request input;
        size_t offset = 0;
        while (offset < sizeof input) {
            ssize_t count = read(STDIN_FILENO, (unsigned char *)&input + offset, sizeof input - offset);
            if (count < 0 && errno == EINTR)
                continue;
            if (count <= 0)
                return count == 0 && !offset ? 0 : 90;
            offset += (size_t)count;
        }
        struct response result = {0};
        errno = EDOM;
        observe(&input, &result);
        result.error = (uint64_t)errno;
        offset = 0;
        while (offset < sizeof result) {
            ssize_t count = write(STDOUT_FILENO, (const unsigned char *)&result + offset,
                                  sizeof result - offset);
            if (count < 0 && errno == EINTR)
                continue;
            if (count <= 0)
                return 91;
            offset += (size_t)count;
        }
    }
}

static inline const unsigned char *shape(const struct request *input, unsigned mode, size_t *extent)
{
    *extent = input->extent % 9;
    switch (mode) {
    case EMPTY:
        *extent = 0;
        return NULL;
    case BAD_BASE:
        *extent += 1;
        return NULL;
    case WRAP:
        *extent += 4;
        return (const unsigned char *)(UINTPTR_MAX - 2);
    default:
        return (const unsigned char *)&input->content;
    }
}
