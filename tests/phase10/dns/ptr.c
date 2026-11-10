#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned queries;

#ifndef OA_PTR_STUB
extern unsigned __real___al_dns_server(void *, struct sockaddr *);
extern FILE *__real_fopen(const char *, const char *);

static unsigned port;

unsigned __wrap___al_dns_server(void *context, struct sockaddr *address)
{
    if (!port)
        return __real___al_dns_server(context, address);
    ++queries;
    struct sockaddr_in server = {.sin_family = AF_INET};
    unsigned char *bytes = (void *)&server.sin_addr;
    unsigned char *service = (void *)&server.sin_port;
    bytes[0] = 127;
    bytes[3] = 1;
    service[0] = (unsigned char)(port >> 8);
    service[1] = (unsigned char)port;
    memcpy(address, &server, sizeof server);
    return sizeof server;
}

FILE *__wrap_fopen(const char *path, const char *mode)
{
    if (port && !strcmp(path, "/etc/hosts"))
        return __real_fopen("tests/phase10/dns/ptr.hosts", mode);
    return __real_fopen(path, mode);
}

#endif

struct observation {
    const char *mode, *address, *host;
    int family, flags, status, expects_query;
    unsigned int capacity;
};

static const struct observation cases[] = {
    {"v4", "192.0.2.77", "mixed.example", AF_INET, NI_NAMEREQD, 0, 1, 32},
    {"v6", "2001:db8::4d", "mixed.example", AF_INET6, NI_NAMEREQD, 0, 1, 32},
    {"mapped", "::ffff:192.0.2.77", "mixed.example", AF_INET6, NI_NAMEREQD, 0, 1, 32},
    {"compatible", "::192.0.2.77", "mixed.example", AF_INET6, NI_NAMEREQD, 0, 1, 32},
    {"tcp", "192.0.2.77", "mixed.example", AF_INET, NI_NAMEREQD, 0, 1, 14},
    {"unrelated", "192.0.2.77", "mixed.example", AF_INET, NI_NAMEREQD, 0, 1, 32},
    {"nxdomain", "192.0.2.77", NULL, AF_INET, NI_NAMEREQD, EAI_NONAME, 1, 32},
    {"fallback", "192.0.2.77", "192.0.2.77", AF_INET, 0, 0, 1, 32},
    {"servfail", "192.0.2.77", NULL, AF_INET, NI_NAMEREQD, EAI_AGAIN, 1, 32},
    {"malformed", "192.0.2.77", NULL, AF_INET, NI_NAMEREQD, EAI_FAIL, 1, 32},
    {"small", "192.0.2.77", NULL, AF_INET, NI_NAMEREQD, EAI_OVERFLOW, 1, 13},
    {"numeric", "192.0.2.77", "192.0.2.77", AF_INET, NI_NUMERICHOST, 0, 0, 32},
    {"local", "192.0.2.44", "local", AF_INET, NI_NAMEREQD | NI_NOFQDN, 0, 0, 32},
    {"loopback", "::1", "localhost", AF_INET6, NI_NAMEREQD, 0, 0, 32},
    {"unspecified", "::", NULL, AF_INET6, NI_NAMEREQD, EAI_NONAME, 0, 32},
};

int main(int argc, char **argv)
{
    if (argc != 3)
        return 90;
    char *end;
    unsigned long parsed = strtoul(argv[1], &end, 10);
    if (*end || !parsed || parsed > 65535)
        return 91;
#ifndef OA_PTR_STUB
    port = (unsigned)parsed;
#endif

    const struct observation *selected = NULL;
    for (size_t i = 0; i < sizeof cases / sizeof *cases; ++i)
        if (!strcmp(argv[2], cases[i].mode))
            selected = &cases[i];
    if (!selected)
        return 92;

    struct sockaddr_in v4 = {.sin_family = AF_INET};
    struct sockaddr_in6 v6 = {.sin6_family = AF_INET6};
    int ipv4 = selected->family == AF_INET;
    void *bytes = ipv4 ? (void *)&v4.sin_addr : (void *)&v6.sin6_addr;
    unsigned char *number = ipv4 ? (void *)&v4.sin_port : (void *)&v6.sin6_port;
    number[0] = 0x10;
    number[1] = 0x92;
    if (inet_pton(selected->family, selected->address, bytes) != 1)
        return 93;
    const struct sockaddr *address = ipv4 ? (void *)&v4 : (void *)&v6;
    socklen_t size = ipv4 ? sizeof v4 : sizeof v6;

    char host[33], service[6], host_before[sizeof host], service_before[sizeof service];
    memset(host, 0x4b, sizeof host);
    memset(service, 0x6d, sizeof service);
    memcpy(host_before, host, sizeof host);
    memcpy(service_before, service, sizeof service);

    errno = EDOM;
    int status = getnameinfo(address, size, host, selected->capacity, service, 5,
                             selected->flags | NI_NUMERICSERV);
    if (status != selected->status || errno != EDOM)
        return 11;
    if (queries != (unsigned)selected->expects_query)
        return 12;
    if (status)
        return memcmp(host, host_before, sizeof host) ||
               memcmp(service, service_before, sizeof service) ? 13 : 0;
    if (host[strlen(selected->host)] || memcmp(host, selected->host, strlen(selected->host)) ||
        memcmp(service, "4242", 5) || service[5] != service_before[5] ||
        host[selected->capacity] != host_before[selected->capacity])
        return 14;
    return 0;
}
