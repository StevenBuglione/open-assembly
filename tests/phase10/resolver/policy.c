#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

union endpoint {
    struct sockaddr_in v4;
    struct sockaddr_in6 v6;
    unsigned char bytes[32];
};

struct server_bank {
    uint32_t count, lengths[2], reserved;
    union endpoint addresses[2];
    unsigned char scratch[32];
    uint32_t timeout, attempts, rotate;
};

_Static_assert(sizeof(union endpoint) == 32 && offsetof(struct server_bank, addresses) == 16 &&
               offsetof(struct server_bank, timeout) == 112, "resolver bank layout");

extern FILE *__real_fopen(const char *, const char *);
extern unsigned __al_dns_config(void *, struct sockaddr *, void *);
extern unsigned __real___al_dns_config(void *, struct sockaddr *, void *);
extern unsigned __real___al_dns_server(void *, struct sockaddr *);
extern int __al_dns_query_timeout(const struct sockaddr *, socklen_t, const char *, unsigned, void *, unsigned);

static const char *config_path, *hosts_path;
static unsigned port;

FILE *__wrap_fopen(const char *path, const char *mode)
{
    if (config_path && !strcmp(path, "/etc/resolv.conf"))
        return __real_fopen(config_path, mode);
    if (hosts_path && !strcmp(path, "/etc/hosts"))
        return __real_fopen(hosts_path, mode);
    return __real_fopen(path, mode);
}

static int port_for(void *record, unsigned length)
{
    union endpoint address;
    if (length != sizeof address.v4 && length != sizeof address.v6)
        return 0;
    memcpy(address.bytes, record, length);
    if (length == sizeof address.v4) {
        uint32_t ip = ntohl(address.v4.sin_addr.s_addr);
        if (address.v4.sin_family != AF_INET || (ip != 0x7f000001 && ip != 0x7f000002) ||
            ntohs(address.v4.sin_port) != 53)
            return 0;
        address.v4.sin_port = htons((uint16_t)port);
    } else {
        const unsigned char loopback[16] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1};
        if (address.v6.sin6_family != AF_INET6 || memcmp(&address.v6.sin6_addr, loopback, sizeof loopback) ||
            ntohs(address.v6.sin6_port) != 53)
            return 0;
        address.v6.sin6_port = htons((uint16_t)port);
    }
    memcpy(record, address.bytes, length);
    return 1;
}

static unsigned reroute(struct sockaddr *primary, unsigned length, void *opaque)
{
    if (!port)
        return length;
    struct server_bank bank;
    memcpy(&bank, opaque, sizeof bank);
    if (bank.count > 2 || !port_for(primary, length))
        return 0;
    for (size_t i = 0; i < bank.count; ++i) {
        if (!port_for(&bank.addresses[i], bank.lengths[i]))
            return 0;
    }
    memcpy(opaque, &bank, sizeof bank);
    return length;
}

unsigned __wrap___al_dns_config(void *context, struct sockaddr *server, void *search)
{
    unsigned length = __real___al_dns_config(context, server, search);
    return search ? reroute(server, length, (unsigned char *)search + 1544) : length;
}

unsigned __wrap___al_dns_server(void *context, struct sockaddr *server)
{
    unsigned length = __real___al_dns_server(context, server);
    return reroute(server, length, (unsigned char *)context + 832);
}

static int endpoint(const union endpoint *value, unsigned length)
{
    int family = length == sizeof value->v4 ? AF_INET : length == sizeof value->v6 ? AF_INET6 : 0;
    if (!family || (family == AF_INET ? value->v4.sin_family : value->v6.sin6_family) != family)
        return 0;
    const void *bytes = family == AF_INET ? (const void *)&value->v4.sin_addr : &value->v6.sin6_addr;
    unsigned service = ntohs(family == AF_INET ? value->v4.sin_port : value->v6.sin6_port);
    char text[64];
    return inet_ntop(family, bytes, text, sizeof text) && printf("%u %s %u\n", length, text, service) > 0;
}

static int config(int reverse)
{
    _Alignas(16) unsigned char context[5184] = {0}, search[1816] = {0};
    union endpoint primary = {0};
    struct server_bank bank;
    unsigned length = __al_dns_config(context, (struct sockaddr *)&primary, reverse ? NULL : search);
    memcpy(&bank, reverse ? context + 832 : search + 1544, sizeof bank);
    if (bank.count > 2 || printf("%u %u %u %u\n", bank.count, bank.timeout, bank.attempts, bank.rotate) < 0 ||
        !endpoint(&primary, length))
        return 11;
    for (size_t i = 0; i < bank.count; ++i)
        if (!endpoint(&bank.addresses[i], bank.lengths[i]))
            return 12;
    return 0;
}

static int number(const char *text, long low, long high, long *result)
{
    char *end;
    long value = strtol(text, &end, 10);
    if (!*text || *end || value < low || value > high)
        return 0;
    *result = value;
    return 1;
}

static int forward(long family, int wanted, unsigned kinds)
{
    struct addrinfo hints = {.ai_family = (int)family, .ai_socktype = SOCK_STREAM, .ai_flags = AI_CANONNAME};
    struct addrinfo *list = (struct addrinfo *)(uintptr_t)0x531;
    errno = EDOM;
    int status = getaddrinfo("node.test.", "19", &hints, &list);
    if (status != wanted || errno != EDOM || (status && list) ||
        (!status && (!list || list == (struct addrinfo *)(uintptr_t)0x531)))
        return 21;
    if (status)
        return 0;
    if (!list->ai_canonname || strcmp(list->ai_canonname, "node.test"))
        return 22;
    unsigned found = 0;
    static const unsigned char v4[] = {192, 0, 2, 9};
    static const unsigned char v6[] = {0x20, 1, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9};
    for (const struct addrinfo *item = list; item; item = item->ai_next) {
        unsigned kind;
        if (item->ai_family == AF_INET && item->ai_addrlen == sizeof(struct sockaddr_in)) {
            const struct sockaddr_in *value = (const void *)item->ai_addr;
            if (ntohs(value->sin_port) != 19 || memcmp(&value->sin_addr, v4, sizeof v4))
                return 23;
            kind = 1;
        } else if (item->ai_family == AF_INET6 && item->ai_addrlen == sizeof(struct sockaddr_in6)) {
            const struct sockaddr_in6 *value = (const void *)item->ai_addr;
            if (ntohs(value->sin6_port) != 19 || memcmp(&value->sin6_addr, v6, sizeof v6))
                return 24;
            kind = 2;
        } else {
            return 25;
        }
        if (found & kind || item->ai_socktype != SOCK_STREAM || item->ai_protocol != IPPROTO_TCP)
            return 26;
        found |= kind;
    }
    freeaddrinfo(list);
    return found == kinds ? 0 : 27;
}

static int reverse(int wanted)
{
    struct sockaddr_in address = {.sin_family = AF_INET, .sin_port = htons(19)};
    if (inet_pton(AF_INET, "192.0.2.77", &address.sin_addr) != 1)
        return 90;
    char host[64], service[8], before[sizeof host], service_before[sizeof service];
    memset(host, 0x4b, sizeof host);
    memset(service, 0x6d, sizeof service);
    memcpy(before, host, sizeof before);
    memcpy(service_before, service, sizeof service_before);
    errno = EDOM;
    int status = getnameinfo((struct sockaddr *)&address, sizeof address, host, sizeof host,
                             service, sizeof service, NI_NAMEREQD | NI_NUMERICSERV);
    if (status != wanted || errno != EDOM)
        return 31;
    if (status)
        return memcmp(host, before, sizeof host) || memcmp(service, service_before, sizeof service) ? 32 : 0;
    return strcmp(host, "reverse.fixture") || strcmp(service, "19") ? 33 : 0;
}

static int invalid_budget(void)
{
    struct sockaddr_in server = {.sin_family = AF_INET, .sin_addr.s_addr = htonl(0x7f000001),
                                 .sin_port = htons((uint16_t)port)};
    const unsigned budgets[] = {0, 30001, UINT32_MAX};
    for (size_t i = 0; i < sizeof budgets / sizeof *budgets; ++i) {
        _Alignas(16) unsigned char answer[1032];
        memset(answer, 0xa5, sizeof answer);
        errno = EDOM;
        int result = __al_dns_query_timeout((const struct sockaddr *)&server, sizeof server,
                                            "node.test", 1, answer, budgets[i]);
        uint32_t count;
        memcpy(&count, answer, sizeof count);
        if (result != EAI_AGAIN || count || errno != EDOM)
            return 41 + (int)i;
    }
    return 0;
}

int main(int argc, char **argv)
{
    if (argc == 3 && (!strcmp(argv[1], "config") || !strcmp(argv[1], "config-reverse"))) {
        config_path = argv[2];
        return config(!strcmp(argv[1], "config-reverse"));
    }
    if (argc == 3 && !strcmp(argv[1], "invalid-budget")) {
        long value;
        if (!number(argv[2], 1, 65535, &value))
            return 91;
        port = (unsigned)value;
        return invalid_budget();
    }
    if (argc != 8 || (strcmp(argv[1], "forward") && strcmp(argv[1], "reverse")))
        return 92;
    config_path = argv[2];
    hosts_path = argv[3];
    long value, family, status, kinds;
    if (!number(argv[4], 1, 65535, &value) || !number(argv[5], 0, 10, &family) ||
        !number(argv[6], -100, 0, &status) || !number(argv[7], 0, 3, &kinds))
        return 93;
    port = (unsigned)value;
    return !strcmp(argv[1], "forward") ? forward(family, (int)status, (unsigned)kinds) : reverse((int)status);
}
