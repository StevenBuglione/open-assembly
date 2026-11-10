#include <errno.h>
#include <stdint.h>
#include <unistd.h>
#include <word_math.h>

int main(void)
{
    for (;;) {
        uint32_t pair[2];
        size_t filled = 0;
        while (filled < sizeof pair) {
            ssize_t count = read(STDIN_FILENO, (unsigned char *)pair + filled, sizeof pair - filled);
            if (count < 0 && errno == EINTR)
                continue;
            if (count <= 0)
                return count == 0 && filled == 0 ? 0 : 90;
            filled += (size_t)count;
        }
        errno = EDOM;
        uint32_t result = word_math_clamp_u32(pair[0], pair[1]);
        if (errno != EDOM || write(STDOUT_FILENO, &result, sizeof result) != sizeof result)
            return 91;
    }
}
