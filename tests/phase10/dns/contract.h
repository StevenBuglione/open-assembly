#ifndef OA_PHASE10_DNS_CONTRACT_H
#define OA_PHASE10_DNS_CONTRACT_H

#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/socket.h>
#include <unistd.h>

extern size_t __al_dns_build(const char *, unsigned int, unsigned int, unsigned char *, size_t);
extern int __al_dns_parse(const unsigned char *, size_t, const unsigned char *, size_t, void *);
extern int __al_dns_query(const struct sockaddr *, socklen_t, const char *, unsigned int, void *);

struct answer {
    uint32_t count, type;
    unsigned char canonical[256];
    unsigned char addresses[16][16];
    unsigned char scratch[512];
};

_Static_assert(sizeof(struct answer) == 1032 && offsetof(struct answer, addresses) == 264,
               "published DNS answer layout");

struct reply { int32_t status; uint32_t length; };

static inline int emit(int32_t status, const void *data, uint32_t length)
{
    const struct reply reply = {status, length};
    return write(STDOUT_FILENO, &reply, sizeof reply) == sizeof reply &&
           (!length || write(STDOUT_FILENO, data, length) == (ssize_t)length);
}

static inline size_t wire_name_length(const unsigned char *name, size_t extent)
{
    size_t used = 0;
    while (used < extent) {
        unsigned width = name[used++];
        if (!width)
            return used;
        if (width > 63 || used + width >= extent)
            return 0;
        used += width;
    }
    return 0;
}

static inline int emit_answer(int status, const struct answer *answer)
{
    if (status)
        return !answer->count && emit(status, NULL, 0);
    size_t owner = wire_name_length(answer->canonical, sizeof answer->canonical);
    if (!owner || !answer->count || answer->count > 16)
        return 0;
    size_t items = 16 * answer->count;
    if (answer->type == 12) {
        items = wire_name_length((const unsigned char *)answer->addresses, sizeof answer->addresses);
        if (answer->count != 1 || !items)
            return 0;
    } else if (answer->type != 1 && answer->type != 28) {
        return 0;
    }
    const struct reply reply = {status, (uint32_t)(8 + owner + items)};
    return write(STDOUT_FILENO, &reply, sizeof reply) == sizeof reply &&
           write(STDOUT_FILENO, answer, 8 + owner) == (ssize_t)(8 + owner) &&
           write(STDOUT_FILENO, answer->addresses, items) == (ssize_t)items;
}

#endif
