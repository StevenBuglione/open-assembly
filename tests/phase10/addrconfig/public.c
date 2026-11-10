#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

extern int __real___al_gai_addrconfig(void);
extern int __real___al_dns_query(const struct sockaddr *, socklen_t, const char *, unsigned, void *);
extern FILE *__real_fopen(const char *, const char *);

static int enabled, snapshot;
static unsigned snapshots, queries;

int __wrap___al_gai_addrconfig(void)
{
    if (!enabled)
        return __real___al_gai_addrconfig();
    ++snapshots;
    return snapshot;
}

FILE *__wrap_fopen(const char *path, const char *mode)
{
    if (enabled && !strcmp(path, "/etc/hosts"))
        return __real_fopen("tests/phase10/addrconfig/hosts", mode);
    if (enabled && !strcmp(path, "/etc/resolv.conf"))
        return __real_fopen("tests/phase10/addrconfig/resolv.conf", mode);
    return __real_fopen(path, mode);
}

struct answer {
    uint32_t count, type;
    unsigned char name[256], address[16][16], scratch[512];
};
_Static_assert(sizeof(struct answer) == 1032, "DNS test ABI");

int __wrap___al_dns_query(const struct sockaddr *server, socklen_t server_size,
                         const char *name, unsigned type, void *output)
{
    if (!enabled)
        return __real___al_dns_query(server, server_size, name, type, output);
    if (strcmp(name, "lookup.fixture") || (type != 1 && type != 28)) {
        queries = 0xeeee;
        return EAI_FAIL;
    }
    queries = (queries << 4) | (type == 1 ? 1 : 2);
    struct answer *answer = output;
    static const unsigned char wire[] = "\006lookup\007fixture";
    memset(answer, 0, sizeof *answer);
    answer->count = 1;
    answer->type = type;
    memcpy(answer->name, wire, sizeof wire);
    static const unsigned char v4[4] = {192, 0, 2, 33};
    static const unsigned char v6[16] = {0x20, 1, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 33};
    if (type == 1)
        memcpy(answer->address[0], v4, sizeof v4);
    else
        memcpy(answer->address[0], v6, sizeof v6);
    return 0;
}

enum { V4 = 1, V6 = 2, MAPPED = 4 };

struct test {
    const char *node;
    int family, flags, mask, status;
    unsigned kinds, dns, octet;
};

static const struct test tests[] = {
    {"192.0.2.77", AF_UNSPEC, AI_NUMERICHOST, 1, 0, V4, 0, 77},
    {"192.0.2.77", AF_UNSPEC, AI_NUMERICHOST, 2, EAI_NONAME, 0, 0, 0},
    {"2001:db8::4d", AF_UNSPEC, AI_NUMERICHOST, 2, 0, V6, 0, 77},
    {"2001:db8::4d", AF_UNSPEC, AI_NUMERICHOST, 1, EAI_NONAME, 0, 0, 0},
    {"192.0.2.77", AF_INET6, AI_NUMERICHOST | AI_V4MAPPED, 1, 0, MAPPED, 0, 77},
    {"192.0.2.77", AF_INET6, AI_NUMERICHOST | AI_V4MAPPED, 2, EAI_NONAME, 0, 0, 0},
    {"localhost", AF_UNSPEC, 0, 3, 0, V4 | V6, 0, 1},
    {"localhost", AF_UNSPEC, 0, 1, 0, V4, 0, 1},
    {"localhost", AF_UNSPEC, 0, 2, 0, V6, 0, 1},
    {"localhost", AF_UNSPEC, 0, 0, EAI_NONAME, 0, 0, 0},
    {"fixture-local", AF_UNSPEC, 0, 3, 0, V4 | V6, 0, 99},
    {"fixture-local", AF_UNSPEC, 0, 1, 0, V4, 0, 99},
    {"fixture-local", AF_UNSPEC, 0, 2, 0, V6, 0, 99},
    {"fixture-local", AF_INET6, AI_ALL | AI_V4MAPPED, 3, 0, V6 | MAPPED, 0, 99},
    {"lookup.fixture", AF_UNSPEC, 0, 1, 0, V4, 1, 33},
    {"lookup.fixture", AF_UNSPEC, 0, 2, 0, V6, 2, 33},
    {"lookup.fixture", AF_UNSPEC, 0, 3, 0, V4 | V6, 0x21, 33},
    {"lookup.fixture", AF_UNSPEC, 0, 0, EAI_NONAME, 0, 0, 0},
    {"lookup.fixture", AF_UNSPEC, 0, EAI_AGAIN, EAI_AGAIN, 0, 0, 0},
    {"lookup.fixture", AF_UNSPEC, 0, EAI_MEMORY, EAI_MEMORY, 0, 0, 0},
    {"lookup.fixture", AF_INET6, AI_V4MAPPED, 1, 0, MAPPED, 1, 33},
    {"lookup.fixture", AF_INET6, AI_ALL | AI_V4MAPPED, 3, 0, V6 | MAPPED, 0x21, 33},
    {"lookup.fixture", AF_INET, 0, 2, EAI_NONAME, 0, 0, 0},
    {NULL, AF_UNSPEC, AI_PASSIVE, 2, 0, V6, 0, 0},
};

static unsigned classify(const struct addrinfo *item, unsigned octet)
{
    if (item->ai_socktype != SOCK_STREAM || item->ai_protocol != IPPROTO_TCP)
        return 0;
    if (item->ai_family == AF_INET && item->ai_addrlen == sizeof(struct sockaddr_in)) {
        const struct sockaddr_in *v4 = (const void *)item->ai_addr;
        const unsigned char *bytes = (const void *)&v4->sin_addr;
        return v4->sin_family == AF_INET && ntohs(v4->sin_port) == 17 && bytes[3] == octet ? V4 : 0;
    }
    if (item->ai_family == AF_INET6 && item->ai_addrlen == sizeof(struct sockaddr_in6)) {
        const struct sockaddr_in6 *v6 = (const void *)item->ai_addr;
        const unsigned char *bytes = (const void *)&v6->sin6_addr;
        const unsigned char mapped[12] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff};
        if (v6->sin6_family != AF_INET6 || ntohs(v6->sin6_port) != 17 || bytes[15] != octet)
            return 0;
        return memcmp(bytes, mapped, sizeof mapped) ? V6 : MAPPED;
    }
    return 0;
}

int main(void)
{
    enabled = 1;
    for (size_t i = 0; i < sizeof tests / sizeof *tests; ++i) {
        const struct test *test = &tests[i];
        snapshot = test->mask;
        snapshots = queries = 0;
        struct addrinfo hints = {.ai_family = test->family, .ai_socktype = SOCK_STREAM,
                                 .ai_flags = test->flags | AI_ADDRCONFIG};
        struct addrinfo *list = (struct addrinfo *)(uintptr_t)0x19b;
        errno = EDOM;
        int status = getaddrinfo(test->node, "17", &hints, &list);
        if (status != test->status || snapshots != 1 || queries != test->dns || errno != EDOM ||
            (status && list) || (!status && (!list || list == (struct addrinfo *)(uintptr_t)0x19b)))
            return 11 + (int)i;
        unsigned kinds = 0;
        for (const struct addrinfo *item = list; item; item = item->ai_next) {
            unsigned kind = classify(item, test->octet);
            if (!kind || kinds & kind)
                return 51 + (int)i;
            kinds |= kind;
        }
        if (kinds != test->kinds)
            return 81 + (int)i;
        freeaddrinfo(list);
    }
    return 0;
}
