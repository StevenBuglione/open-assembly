#define _GNU_SOURCE
#include <errno.h>
#include <limits.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

_Static_assert(sizeof(struct addrinfo) == 48 && offsetof(struct addrinfo, ai_addr) == 24 &&
               offsetof(struct addrinfo, ai_canonname) == 32 && offsetof(struct addrinfo, ai_next) == 40,
               "Linux LP64 addrinfo layout");

static int match4(const struct addrinfo *entry, const unsigned char bytes[4],
                  unsigned port, int type, int protocol)
{
    if (!entry || entry->ai_family != AF_INET || entry->ai_addrlen != sizeof(struct sockaddr_in) ||
        entry->ai_socktype != type || entry->ai_protocol != protocol || !entry->ai_addr)
        return 0;
    const struct sockaddr_in *address = (const void *)entry->ai_addr;
    const unsigned char *network_port = (const void *)&address->sin_port;
    return address->sin_family == AF_INET && !memcmp(&address->sin_addr, bytes, 4) &&
           256u * network_port[0] + network_port[1] == port;
}

static int match6(const struct addrinfo *entry, const unsigned char bytes[16],
                  unsigned port, int type, int protocol)
{
    if (!entry || entry->ai_family != AF_INET6 || entry->ai_addrlen != sizeof(struct sockaddr_in6) ||
        entry->ai_socktype != type || entry->ai_protocol != protocol || !entry->ai_addr)
        return 0;
    const struct sockaddr_in6 *address = (const void *)entry->ai_addr;
    const unsigned char *network_port = (const void *)&address->sin6_port;
    return address->sin6_family == AF_INET6 && !memcmp(&address->sin6_addr, bytes, 16) &&
           256u * network_port[0] + network_port[1] == port;
}

static int forward_numeric(void)
{
    struct addrinfo hints = {.ai_family = AF_INET, .ai_socktype = SOCK_STREAM,
                             .ai_flags = AI_NUMERICHOST | AI_NUMERICSERV | AI_CANONNAME};
    struct addrinfo sentinel, *result = &sentinel;
    char node[] = "192.0.2.43";
    const unsigned char bytes[] = {192, 0, 2, 43};
    errno = EDOM;
    if (getaddrinfo(node, "00080", &hints, &result) || !result || result == &sentinel ||
        !match4(result, bytes, 80, SOCK_STREAM, IPPROTO_TCP) || result->ai_next ||
        !result->ai_canonname || strcmp(result->ai_canonname, node) || errno != EDOM)
        return 11;
    node[0] = '9';
    if (strcmp(result->ai_canonname, "192.0.2.43"))
        return 12;
    freeaddrinfo(result);
    if (errno != EDOM)
        return 13;

    hints.ai_family = AF_INET6;
    hints.ai_flags = AI_NUMERICHOST | AI_NUMERICSERV | AI_V4MAPPED;
    hints.ai_socktype = SOCK_DGRAM;
    result = &sentinel;
    const unsigned char mapped[16] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 192, 0, 2, 43};
    if (getaddrinfo("192.0.2.43", "65535", &hints, &result) || !result || result == &sentinel ||
        !match6(result, mapped, 65535, SOCK_DGRAM, IPPROTO_UDP) || result->ai_next || errno != EDOM)
        return 14;
    freeaddrinfo(result);
    return errno == EDOM ? 0 : 15;
}

#ifndef OA_PHASE10_HOST
static int forward_policy(void)
{
    struct addrinfo hints = {.ai_family = AF_UNSPEC, .ai_flags = AI_PASSIVE};
    struct addrinfo sentinel, *result = &sentinel;
    const unsigned char zero[16] = {0};
    errno = EDOM;
    /* RFC 3493 §6.1 requires at least one of node and service. */
    if (getaddrinfo(NULL, NULL, &hints, &result) != EAI_NONAME || result || errno != EDOM)
        return 19;
    result = &sentinel;
    if (getaddrinfo(NULL, "0", &hints, &result) || !result || result == &sentinel || errno != EDOM)
        return 20;
    const struct addrinfo *entry = result;
    if (!match6(entry, zero, 0, SOCK_STREAM, IPPROTO_TCP))
        return 21;
    entry = entry->ai_next;
    if (!match6(entry, zero, 0, SOCK_DGRAM, IPPROTO_UDP))
        return 22;
    entry = entry->ai_next;
    if (!match4(entry, zero, 0, SOCK_STREAM, IPPROTO_TCP))
        return 23;
    entry = entry->ai_next;
    if (!match4(entry, zero, 0, SOCK_DGRAM, IPPROTO_UDP) || entry->ai_next)
        return 24;
    freeaddrinfo(result);

    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_NUMERICHOST | AI_NUMERICSERV;
    const struct { const char *node, *service; int status; } invalid[] = {
        {"hostname.invalid", "80", EAI_NONAME},
        {"192.0.2.43", "service", EAI_NONAME},
        {"192.0.2.43", "65536", EAI_NONAME},
    };
    for (size_t i = 0; i < sizeof invalid / sizeof invalid[0]; ++i) {
        result = &sentinel;
        errno = EDOM;
        if (getaddrinfo(invalid[i].node, invalid[i].service, &hints, &result) != invalid[i].status ||
            result || errno != EDOM)
            return 25 + (int)i;
    }
    hints.ai_flags = INT_MAX;
    result = &sentinel;
    if (getaddrinfo("192.0.2.43", "80", &hints, &result) != EAI_BADFLAGS || result || errno != EDOM)
        return 28;
    return 0;
}
#endif

static int reverse_numeric(void)
{
    struct sockaddr_in address = {.sin_family = AF_INET};
    unsigned char *port = (void *)&address.sin_port;
    port[0] = 0xff;
    port[1] = 0xff;
    const unsigned char bytes[] = {198, 51, 100, 26};
    memcpy(&address.sin_addr, bytes, sizeof bytes);
    const int flags = NI_NUMERICHOST | NI_NUMERICSERV;
    char host[32], service[8];
    memset(host, '#', sizeof host);
    memset(service, '#', sizeof service);
    errno = EDOM;
    if (getnameinfo((const struct sockaddr *)&address, sizeof address,
                    host, 14, service, 6, flags) ||
        strcmp(host, "198.51.100.26") || strcmp(service, "65535") ||
        host[14] != '#' || service[6] != '#' || errno != EDOM)
        return 31;
    if (getnameinfo((const struct sockaddr *)&address, sizeof address,
                    NULL, 0, service, sizeof service, NI_NUMERICSERV) ||
        strcmp(service, "65535") || errno != EDOM)
        return 32;
    return 0;
}

#ifndef OA_PHASE10_HOST
static int reverse_policy(void)
{
    struct sockaddr_in6 address = {.sin6_family = AF_INET6, .sin6_scope_id = 17};
    const unsigned char bytes[] = {0x20, 1, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2};
    memcpy(&address.sin6_addr, bytes, sizeof bytes);
    char host[64], service[8], saved_host[64], saved_service[8];
    memset(host, '#', sizeof host);
    memset(service, '$', sizeof service);
    memcpy(saved_host, host, sizeof host);
    memcpy(saved_service, service, sizeof service);
    int flags = NI_NUMERICHOST | NI_NUMERICSERV;
    errno = EDOM;
    if (getnameinfo((const struct sockaddr *)&address, sizeof address,
                    host, sizeof host, service, 1, flags) != EAI_OVERFLOW ||
        memcmp(host, saved_host, sizeof host) || memcmp(service, saved_service, sizeof service) ||
        errno != EDOM)
        return 35;
    if (getnameinfo((const struct sockaddr *)&address, sizeof address - 1,
                    host, sizeof host, service, sizeof service, flags) != EAI_FAMILY ||
        getnameinfo((const struct sockaddr *)&address, sizeof address,
                    host, sizeof host, service, sizeof service, INT_MAX) != EAI_BADFLAGS ||
        errno != EDOM)
        return 36;
    if (getnameinfo((const struct sockaddr *)&address, sizeof address,
                    host, sizeof host, service, sizeof service, flags) ||
        strcmp(host, "2001:db8::2%17") || strcmp(service, "0") || errno != EDOM)
        return 37;
    return 0;
}
#endif

static int errors(void)
{
    const int codes[] = {0, EAI_BADFLAGS, EAI_NONAME, EAI_AGAIN, EAI_FAIL,
                         EAI_FAMILY, EAI_SOCKTYPE, EAI_SERVICE, EAI_MEMORY,
                         EAI_SYSTEM, EAI_OVERFLOW, INT_MAX, INT_MIN};
    errno = EDOM;
    for (size_t i = 0; i < sizeof codes / sizeof codes[0]; ++i) {
        const char *text = gai_strerror(codes[i]);
        if (!text || !*text || errno != EDOM)
            return 40;
        size_t size = strlen(text) + 1;
        char original[256];
        if (size > sizeof original)
            return 41;
        memcpy(original, text, size);
        const char *other = gai_strerror(EAI_FAIL);
        if (!other || !*other || memcmp(original, text, size) || strcmp(gai_strerror(codes[i]), original) ||
            errno != EDOM)
            return 42;
    }
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "forward"))
        return forward_numeric();
    if (!strcmp(argv[1], "reverse"))
        return reverse_numeric();
#ifndef OA_PHASE10_HOST
    if (!strcmp(argv[1], "forward-policy"))
        return forward_policy();
    if (!strcmp(argv[1], "reverse-policy"))
        return reverse_policy();
#endif
    if (!strcmp(argv[1], "errors"))
        return errors();
    return 91;
}
