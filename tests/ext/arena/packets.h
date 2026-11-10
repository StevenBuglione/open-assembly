#include <arena.h>
#include <errno.h>
#include <stdint.h>
#include <unistd.h>

struct request {
    size_t state[3], a, b, flags, output;
};

struct response {
    int64_t status;
    size_t state[3], output, error;
};

_Static_assert(sizeof(struct request) == 56 && sizeof(struct response) == 48, "packet layout");

static void observe(struct request *, struct response *);

int main(void)
{
    for (;;) {
        struct request input;
        size_t done = 0;
        while (done < sizeof input) {
            ssize_t count = read(STDIN_FILENO, (unsigned char *)&input + done, sizeof input - done);
            if (count < 0 && errno == EINTR)
                continue;
            if (count <= 0)
                return count == 0 && !done ? 0 : 90;
            done += (size_t)count;
        }
        struct response result = {0, {input.state[0], input.state[1], input.state[2]}, input.output, 0};
        errno = EDOM;
        observe(&input, &result);
        result.error = (size_t)errno;
        done = 0;
        while (done < sizeof result) {
            ssize_t count = write(STDOUT_FILENO, (unsigned char *)&result + done, sizeof result - done);
            if (count < 0 && errno == EINTR)
                continue;
            if (count <= 0)
                return 91;
            done += (size_t)count;
        }
    }
}
