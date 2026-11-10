#include <errno.h>
#include <json.h>
#include <stdint.h>
#include <stdio.h>

enum { MAX_INPUT = 1 << 18 };
static unsigned char input[MAX_INPUT];
static size_t workspace[3 + 2 * (MAX_INPUT + 1)];
static size_t tokens[4 * (MAX_INPUT + 1)];
static const size_t canary = UINT64_C(0x481b998a0f32755c);

int main(void)
{
    uint32_t length;
    size_t count;
    while ((count = fread(&length, 1, sizeof length, stdin)) == sizeof length) {
        if (length > MAX_INPUT || fread(input, 1, length, stdin) != length)
            return 90;
        size_t capacity = (size_t)length + 1;
        for (size_t i = 0; i < 4 * capacity; ++i)
            tokens[i] = canary;
        errno = EDOM;
        int64_t status = json_parse(input, length, workspace, capacity, tokens, capacity);
        if (errno != EDOM || status > (int64_t)capacity)
            return 91;
        for (size_t i = status > 0 ? 4 * (size_t)status : 0; i < 4 * capacity; ++i)
            if (tokens[i] != canary)
                return 92;
        if (fwrite(&status, sizeof status, 1, stdout) != 1)
            return 93;
    }
    return count || ferror(stdin) || fflush(stdout) ? 94 : 0;
}
