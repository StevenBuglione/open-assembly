#define _GNU_SOURCE
#ifdef OA_PHASE6_HOST
#define OA_PHASE4_HOST
#endif

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

#include "../phase4/file.h"

#undef feof
#undef ferror
#undef clearerr
#undef fileno

enum { EOF_QUERY, ERROR_QUERY, CLEAR, DESCRIPTOR };
static const unsigned char sample[] = {0, 0xff, 'R', '\n', 0x80, 'X', 'Y', 'Z'};

struct packet { uint64_t actions, byte; };
struct result {
    uint64_t before, after, value, error, position_before, position_after, prepared, follow;
};
_Static_assert(sizeof(struct packet) == 16 && sizeof(struct result) == 64, "LP64 packet widths");

static unsigned indicators(FILE *stream)
{
    unsigned end = feof(stream) != 0, error = ferror(stream) != 0;
    return end | (error << 1);
}

static int borrowed(int fd, const struct file_fixture *file)
{
    unsigned char bytes[sizeof sample];
    if (fd < 0 || fd == file->fd)
        return 0;
    long flags = kernel_call(__NR_fcntl, fd, F_GETFL, 0, 0, 0, 0);
    return flags >= 0 && (flags & O_ACCMODE) == O_RDONLY &&
           kernel_call(__NR_pread64, fd, (long)bytes, sizeof bytes, 0, 0, 0) == (long)sizeof bytes &&
           bytes_equal(bytes, sample, sizeof bytes);
}

static int observe(FILE *stream, const struct file_fixture *file, unsigned operation,
                   const struct packet *packet, struct result *result)
{
    rewind(stream);
    unsigned reads = (unsigned)(packet->actions & 15);
    int last = -2;
    if ((packet->actions & 16) && fputc('X', stream) != EOF)
        return 0;
    for (unsigned i = 0; i < reads; ++i)
        last = fgetc(stream);
    if ((packet->actions & 32) && fputc('Y', stream) != EOF)
        return 0;
    int pushed = (unsigned char)packet->byte;
    if ((packet->actions & 64) && reads && ungetc(pushed, stream) != pushed)
        return 0;
    if ((packet->actions & 128) && fseek(stream, (long)((packet->byte >> 8) % (sizeof sample + 1)), SEEK_SET))
        return 0;

    result->prepared = (uint64_t)(int64_t)last;
    result->before = indicators(stream);
    result->position_before = (uint64_t)ftell(stream);
    errno = EDOM;
    int fd = -1;
    switch (operation) {
    case EOF_QUERY: result->value = !!feof(stream); break;
    case ERROR_QUERY: result->value = !!ferror(stream); break;
    case CLEAR: clearerr(stream); break;
    default: fd = fileno(stream); break;
    }
    result->error = (uint64_t)errno;
    result->after = indicators(stream);
    result->position_after = (uint64_t)ftell(stream);
    if (operation == DESCRIPTOR)
        result->value = borrowed(fd, file);
    if (packet->actions & 256) {
        int next = fgetc(stream);
        result->follow = ((uint64_t)(unsigned)(next + 1) << 2) | indicators(stream);
    }
    return 1;
}

static int transfer(void *memory, size_t size, int writing)
{
    size_t offset = 0;
    while (offset < size) {
        unsigned char *bytes = (unsigned char *)memory + offset;
        ssize_t count = writing ? write(STDOUT_FILENO, bytes, size - offset) :
                                  read(STDIN_FILENO, bytes, size - offset);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            return count == 0 && !offset && !writing ? 0 : -1;
        offset += (size_t)count;
    }
    return 1;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    const char *const names[] = {"feof", "ferror", "clearerr", "fileno"};
    unsigned operation = 0;
    while (operation < sizeof names / sizeof *names && !same(argv[1], names[operation]))
        ++operation;
    if (operation == sizeof names / sizeof *names)
        return 91;
    struct file_fixture file;
    if (!file_fixture_open(&file, sample, sizeof sample))
        return 92;
    FILE *stream = fopen(file.path, "rb");
    if (!stream)
        return 93;
    struct packet packet;
    int received;
    while ((received = transfer(&packet, sizeof packet, 0)) == 1) {
        struct result result = {0};
        if (!observe(stream, &file, operation, &packet, &result))
            return 94;
        if (transfer(&result, sizeof result, 1) != 1)
            return 95;
    }
    return received < 0 || fclose(stream) || !file_fixture_close(&file) ? 96 : 0;
}
