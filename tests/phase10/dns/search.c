#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern FILE *__real_fopen(const char *, const char *);
extern unsigned __al_dns_config(void *, struct sockaddr *, void *);
extern unsigned __real___al_dns_config(void *, struct sockaddr *, void *);

struct search_data {
    uint32_t count, ndots;
    char suffix[6][256];
    unsigned char scratch[272];
};
union server_address { struct sockaddr_in v4; struct sockaddr_in6 v6; unsigned char bytes[32]; };
_Static_assert(sizeof(struct search_data) == 1816 && sizeof(union server_address) == 32, "resolver config ABI");

static const char *resolver_file, *hosts_file;
static unsigned port, configurations;

FILE *__wrap_fopen(const char *path, const char *mode)
{
    if (resolver_file && !strcmp(path, "/etc/resolv.conf"))
        return __real_fopen(resolver_file, mode);
    if (hosts_file && !strcmp(path, "/etc/hosts"))
        return __real_fopen(hosts_file, mode);
    return __real_fopen(path, mode);
}

unsigned __wrap___al_dns_config(void *context, struct sockaddr *server, void *search)
{
    ++configurations;
    unsigned length = __real___al_dns_config(context, server, search);
    if (port && length == sizeof(struct sockaddr_in) && server->sa_family == AF_INET) {
        struct sockaddr_in *v4 = (void *)server;
        if (v4->sin_addr.s_addr != htonl(0x7f000001) || ntohs(v4->sin_port) != 53)
            return 0;
        v4->sin_port = htons((uint16_t)port);
    }
    return length;
}

static int configure(int without_search)
{
    _Alignas(16) unsigned char context[5184] = {0};
    union server_address server;
    struct search_data search;
    memset(&server, 0xa5, sizeof server);
    memset(&search, 0xa5, sizeof search);
    unsigned length = __al_dns_config(context, (struct sockaddr *)&server,
                                      without_search ? NULL : &search);
    int family = length == sizeof server.v4 ? AF_INET : length == sizeof server.v6 ? AF_INET6 : 0;
    if (!family || configurations != 1 ||
        (family == AF_INET ? server.v4.sin_family : server.v6.sin6_family) != family)
        return 11;
    const void *bytes = family == AF_INET ? (const void *)&server.v4.sin_addr : &server.v6.sin6_addr;
    unsigned service = ntohs(family == AF_INET ? server.v4.sin_port : server.v6.sin6_port);
    char text[64];
    if (!inet_ntop(family, bytes, text, sizeof text))
        return 12;
    if (without_search)
        return printf("%u %s %u\n", length, text, service) < 0 ? 13 : 0;
    if (search.count > 6 || search.ndots > 15 ||
        printf("%u %s %u %u %u\n", length, text, service, search.count, search.ndots) < 0)
        return 14;
    for (unsigned i = 0; i < search.count; ++i) {
        if (!memchr(search.suffix[i], 0, sizeof search.suffix[i]) || puts(search.suffix[i]) == EOF)
            return 15;
    }
    return 0;
}

static int number(const char *text, long minimum, long maximum, long *result)
{
    char *end;
    long value = strtol(text, &end, 10);
    if (!*text || *end || value < minimum || value > maximum)
        return 0;
    *result = value;
    return 1;
}

static int public_lookup(char **args)
{
    long requested_port, family, flags, expected, config_count, kinds;
    if (!number(args[0], 1, 65535, &requested_port) || !number(args[1], 0, 10, &family) ||
        !number(args[2], 0, 1024, &flags) || !number(args[3], -100, 0, &expected) ||
        !number(args[4], -1, 1, &config_count) || !number(args[5], 0, 3, &kinds))
        return 91;
    port = (unsigned)requested_port;
    const char *node = args[6], *canonical = args[7];
    struct addrinfo hints = {.ai_family = (int)family, .ai_socktype = SOCK_STREAM, .ai_flags = (int)flags};
    if (strcmp(canonical, "-"))
        hints.ai_flags |= AI_CANONNAME;
    struct addrinfo *list = (struct addrinfo *)(uintptr_t)0x51a;
    errno = EDOM;
    int status = getaddrinfo(node, "8080", &hints, &list);
    if (status != expected || errno != EDOM ||
        (config_count >= 0 && configurations != (unsigned)config_count) ||
        (status && list) || (!status && (!list || list == (struct addrinfo *)(uintptr_t)0x51a)))
        return 21;
    if (status)
        return 0;
    if ((hints.ai_flags & AI_CANONNAME) && (!list->ai_canonname || strcmp(list->ai_canonname, canonical)))
        return 22;

    unsigned found = 0;
    for (const struct addrinfo *item = list; item; item = item->ai_next) {
        unsigned kind;
        if (item->ai_socktype != SOCK_STREAM || item->ai_protocol != IPPROTO_TCP)
            return 23;
        if (item->ai_family == AF_INET && item->ai_addrlen == sizeof(struct sockaddr_in)) {
            const struct sockaddr_in *v4 = (const void *)item->ai_addr;
            if (v4->sin_family != AF_INET || ntohs(v4->sin_port) != 8080)
                return 24;
            kind = 1;
        } else if (item->ai_family == AF_INET6 && item->ai_addrlen == sizeof(struct sockaddr_in6)) {
            const struct sockaddr_in6 *v6 = (const void *)item->ai_addr;
            if (v6->sin6_family != AF_INET6 || ntohs(v6->sin6_port) != 8080)
                return 25;
            kind = 2;
        } else {
            return 26;
        }
        if (kind & found)
            return 27;
        found |= kind;
    }
    freeaddrinfo(list);
    return found == (unsigned)kinds ? 0 : 28;
}

int main(int argc, char **argv)
{
    if (argc < 3)
        return 90;
    resolver_file = argv[2];
    if (argc == 3 && (!strcmp(argv[1], "config") || !strcmp(argv[1], "server")))
        return configure(!strcmp(argv[1], "server"));
    if (argc != 12 || strcmp(argv[1], "lookup"))
        return 90;
    hosts_file = argv[3];
    return public_lookup(argv + 4);
}
