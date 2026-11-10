#include "contract.h"
#include <string.h>

extern long __al_syscall(long, long, long, long, long, long, long);
struct aux_entry { unsigned long type, value; };
extern const struct aux_entry *const __al_auxv;

struct request { uint32_t mode, size, query_or_capacity, type, id; };
enum { PLANES = 3, MAX_RESPONSE = 65535, MAX_NAME = 511, MAX_QUERY = 512 };
enum { MAP = 9, PROTECT = 10, UNMAP = 11, AT_PAGESZ = 6 };

static size_t page, extent;
static unsigned char *planes[PLANES];

static int read_all(void *address, size_t length)
{
    unsigned char *data = address;
    size_t offset = 0;
    while (offset < length) {
        ssize_t count = read(STDIN_FILENO, data + offset, length - offset);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            return !count && !offset ? 0 : -1;
        offset += (size_t)count;
    }
    return 1;
}

static int map_planes(void)
{
    for (const struct aux_entry *item = __al_auxv; item->type; ++item) {
        if (item->type == AT_PAGESZ)
            page = item->value;
    }
    if (page < 1024)
        return 0;
    extent = (MAX_RESPONSE + page - 1) / page * page;
    for (int i = 0; i < PLANES; ++i) {
        long address = __al_syscall(MAP, 0, extent + 2 * page, 0, 0x22, -1, 0);
        if (address < 0)
            return 0;
        planes[i] = (void *)(address + page);
    }
    return 1;
}

static int permission(int plane, int flags)
{
    return __al_syscall(PROTECT, (long)planes[plane], extent, flags, 0, 0, 0) == 0;
}

static unsigned char *edge(int plane, size_t bytes, int right)
{
    return planes[plane] + (right ? extent - bytes : 0);
}

static int build(const struct request *input, int right)
{
    uint32_t name_size = input->size, capacity = input->query_or_capacity;
    if (name_size > MAX_NAME || capacity > MAX_QUERY || !permission(0, 3) || !permission(2, 3))
        return 0;
    unsigned char *name = edge(0, name_size + 1, right), *output = edge(2, capacity, right);
    if (read_all(name, name_size) != 1)
        return 0;
    name[name_size] = 0;
    if (!permission(0, 1))
        return 0;
    memset(planes[2], 0xa5, extent);
    errno = EDOM;
    size_t count = __al_dns_build((const char *)name, input->type, input->id, output, capacity);
    if (count > capacity || errno != EDOM || (right ? output[-1] : output[capacity]) != 0xa5)
        return 0;
    for (size_t i = count; i < capacity; ++i) {
        if (output[i] != 0xa5)
            return 0;
    }
    return emit((int32_t)count, output, (uint32_t)count);
}

static int parse(const struct request *input, int right)
{
    size_t length = input->size, query_size = input->query_or_capacity;
    if (length > MAX_RESPONSE || query_size > MAX_QUERY ||
        !permission(0, 3) || !permission(1, 3) || !permission(2, 3))
        return 0;
    unsigned char *response = edge(0, length, right), *query = edge(1, query_size, right);
    if (read_all(response, length) != 1 || read_all(query, query_size) != 1 ||
        !permission(0, 1) || !permission(1, 1))
        return 0;
    struct answer *answer = (void *)edge(2, sizeof *answer, right);
    memset(planes[2], 0xa5, extent);
    errno = EDOM;
    int status = __al_dns_parse(response, length, query, query_size, answer);
    unsigned char *bytes = (void *)answer;
    if (errno != EDOM || (right ? bytes[-1] : bytes[sizeof *answer]) != 0xa5)
        return 0;
    return emit_answer(status, answer);
}

int main(int argc, char **argv)
{
    if (argc != 2 || (strcmp(argv[1], "left") && strcmp(argv[1], "right")) || !map_planes())
        return 90;
    int right = !strcmp(argv[1], "right");
    struct request input;
    int status;
    while ((status = read_all(&input, sizeof input)) == 1) {
        if (input.mode == 0) {
            if (!build(&input, right))
                return 91;
        } else if (input.mode == 1) {
            if (!parse(&input, right))
                return 92;
        } else {
            return 93;
        }
    }
    if (status)
        return 94;
    for (int i = 0; i < PLANES; ++i) {
        if (__al_syscall(UNMAP, (long)(planes[i] - page), extent + 2 * page, 0, 0, 0, 0))
            return 95;
    }
    return 0;
}
