#include "endpoint.h"
#include <sys/mman.h>

enum { PAGE = 4096, ARENA = 3 * PAGE, FIFO_MODE = 0010000, TYPE_MASK = 0170000 };
static const uint64_t canary = UINT64_C(0xac6f1b8572e43d09);

struct packet { uint64_t selector, payload; };
struct response {
    int64_t status;
    uint64_t error, memory, order, flags, count, payload, eof;
};
_Static_assert(sizeof(struct packet) == 16 && sizeof(struct response) == 64, "LP64 packet widths");

static int transfer(int fd, void *memory, size_t size, int output)
{
    size_t offset = 0;
    while (offset < size) {
        unsigned char *bytes = (unsigned char *)memory + offset;
        long count = output ? raw_write(fd, bytes, size - offset) : raw_read(fd, bytes, size - offset);
        if (count == -EINTR)
            continue;
        if (count <= 0)
            return !count && !offset && !output ? 0 : -1;
        offset += (size_t)count;
    }
    return 1;
}

static int protect(unsigned char *page, int protection)
{
    return kernel_call(__NR_mprotect, (long)page, PAGE, protection, 0, 0, 0) == 0;
}

static int free_descriptor_slots(int slots[2])
{
    if (kernel_call(__NR_pipe2, (long)slots, 0, 0, 0, 0, 0))
        return 0;
    return raw_close(slots[0]) == 0 && raw_close(slots[1]) == 0;
}

static int same_pipe(const int fd[2])
{
    struct kernel_stat left, right;
    return raw_fstat(fd[0], &left) == 0 && raw_fstat(fd[1], &right) == 0 &&
           (left.mode & TYPE_MASK) == FIFO_MODE && (right.mode & TYPE_MASK) == FIFO_MODE &&
           left.device == right.device && left.inode == right.inode;
}

static void exchange(const int fd[2], const struct packet *packet, struct response *out)
{
    struct endpoint_observation actual = endpoints(fd);
    out->order = actual.order;
    out->flags = actual.flags;
    if (actual.order != 7 || !same_pipe(fd))
        return;
    out->order |= 8;
    unsigned char received[8], sent[8];
    if ((actual.flags & 4) && raw_read(fd[0], received, 1) != -EAGAIN) {
        raw_close(fd[0]);
        raw_close(fd[1]);
        return;
    }
    out->order |= 16;
    size_t size = 1 + ((packet->selector >> 8) & 7);
    for (size_t i = 0; i < size; ++i)
        sent[i] = (unsigned char)(packet->payload >> (i * 8));
    if (raw_write(fd[1], sent, size) == (long)size) {
        long count = raw_read(fd[0], received, size);
        out->count = (uint64_t)count;
        if (count > 0 && count <= (long)size)
            for (long i = 0; i < count; ++i)
                out->payload |= (uint64_t)received[i] << (i * 8);
    }
    if (raw_close(fd[1]))
        out->eof = UINT64_MAX;
    else
        out->eof = (uint64_t)raw_read(fd[0], received, 1);
    if (raw_close(fd[0]))
        out->eof = UINT64_MAX;
}

static int observe(unsigned char *region, int with_flags, const struct packet *packet,
                   struct response *out)
{
    unsigned char *middle = region + PAGE;
    int right = (packet->selector & 1) != 0;
    int *descriptors = (void *)(right ? middle + PAGE - 2 * sizeof(int) : middle);
    uint64_t *guard = (void *)(right ? (unsigned char *)descriptors - sizeof canary
                                    : (unsigned char *)descriptors + 2 * sizeof(int));
    int flags = 0;
    if (with_flags && (packet->selector & 2))
        flags |= O_CLOEXEC;
    if (with_flags && (packet->selector & 4))
        flags |= O_NONBLOCK;
    int bad_flags = with_flags && (packet->selector & 31) == 30;
    int bad_pointer = (packet->selector & 127) == 127;
    if (bad_flags)
        flags |= O_APPEND;
    int expect_failure = bad_flags || bad_pointer;
    int free_slots[2];
    if (expect_failure && !free_descriptor_slots(free_slots))
        return 0;

    *guard = canary;
    unsigned char *protected = region + 2 * PAGE;
    if (bad_pointer) {
        if (!protect(protected, PROT_READ | PROT_WRITE))
            return 0;
        descriptors = (void *)protected;
    }
    descriptors[0] = SENTINEL_LEFT;
    descriptors[1] = SENTINEL_RIGHT;
    if (bad_pointer && !protect(protected, PROT_NONE))
        return 0;

    errno = 0x500 + (int)((packet->selector >> 32) & 255);
    out->status = with_flags ? pipe2(descriptors, flags) : pipe(descriptors);
    out->error = (uint64_t)errno;
    if (bad_pointer && !protect(protected, PROT_READ | PROT_WRITE))
        return 0;
    out->memory = *guard == canary;
    if (expect_failure) {
        if (descriptors[0] == SENTINEL_LEFT && descriptors[1] == SENTINEL_RIGHT)
            out->memory |= 2;
        if (raw_fcntl(free_slots[0], K_F_GETFD, 0) == -EBADF &&
            raw_fcntl(free_slots[1], K_F_GETFD, 0) == -EBADF)
            out->memory |= 4;
    } else if (!out->status && descriptors[0] >= 0 && descriptors[1] >= 0) {
        out->memory |= 2;
        exchange(descriptors, packet, out);
    }
    return !bad_pointer || protect(protected, PROT_NONE);
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    int with_flags = same_text(argv[1], "pipe2");
    if (!with_flags && !same_text(argv[1], "pipe"))
        return 91;
    long raw = kernel_call(__NR_mmap, 0, ARENA, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (raw < 0)
        return 92;
    unsigned char *region = (void *)(uintptr_t)raw;
    if (!protect(region + PAGE, PROT_READ | PROT_WRITE))
        return 93;
    struct packet packet;
    int received;
    while ((received = transfer(STDIN_FILENO, &packet, sizeof packet, 0)) == 1) {
        struct response output = {0};
        if (!observe(region, with_flags, &packet, &output) ||
            transfer(STDOUT_FILENO, &output, sizeof output, 1) != 1)
            return 94;
    }
    return received < 0 || kernel_call(__NR_munmap, raw, ARENA, 0, 0, 0, 0) ? 95 : 0;
}
