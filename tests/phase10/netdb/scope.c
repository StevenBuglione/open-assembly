#define _GNU_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <stdint.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

struct interface_request {
    char name[16];
    union { uint32_t index; uint64_t storage[3]; } data;
};
_Static_assert(sizeof(struct interface_request) == 40, "Linux x86-64 ifreq ABI");

static uint32_t loopback_index(void)
{
    int fd = socket(AF_INET6, SOCK_DGRAM | SOCK_CLOEXEC, 0);
    if (fd < 0)
        return 0;
    struct interface_request request = {.name = "lo"};
    int status = ioctl(fd, 0x8933, &request);
    return close(fd) || status ? 0 : request.data.index;
}

static int preserved(void)
{
#ifdef OA_PHASE10_HOST
    return 1;
#else
    return errno == EDOM;
#endif
}

static int numeric(const char *node, const char *address_text, uint32_t scope, const char *reverse_text)
{
    struct addrinfo hints = {.ai_family = AF_INET6, .ai_socktype = SOCK_STREAM,
                             .ai_flags = AI_NUMERICHOST | AI_NUMERICSERV | AI_CANONNAME};
    struct addrinfo *list = NULL;
    errno = EDOM;
    if (getaddrinfo(node, "2049", &hints, &list) || !list || list->ai_next ||
        list->ai_family != AF_INET6 || list->ai_addrlen != sizeof(struct sockaddr_in6) ||
        !list->ai_canonname || strcmp(list->ai_canonname, node) || !preserved())
        return 0;
    const struct sockaddr_in6 *address = (const void *)list->ai_addr;
    struct in6_addr expected;
    if (inet_pton(AF_INET6, address_text, &expected) != 1 || address->sin6_family != AF_INET6 ||
        address->sin6_scope_id != scope || ntohs(address->sin6_port) != 2049 ||
        memcmp(&address->sin6_addr, &expected, sizeof expected))
        return 0;
    char host[96], service[16];
    errno = EDOM;
    int status = getnameinfo(list->ai_addr, list->ai_addrlen, host, sizeof host, service, sizeof service,
                             NI_NUMERICHOST | NI_NUMERICSERV);
    int matched = !status && !strcmp(host, reverse_text) && !strcmp(service, "2049") && preserved();
    freeaddrinfo(list);
    return matched;
}

static int shared(void)
{
    uint32_t index = loopback_index();
    if (!index)
        return 90;
    if (!numeric("fe80::1%lo", "fe80::1", index, "fe80::1%lo"))
        return 11;
    if (!numeric("ff02::1%lo", "ff02::1", index, "ff02::1%lo"))
        return 12;
    if (!numeric("2001:db8::7%00031", "2001:db8::7", 31, "2001:db8::7%31"))
        return 13;
    if (!numeric("fe80::8%0", "fe80::8", 0, "fe80::8"))
        return 14;
    if (!numeric("fe80::9%4294967295", "fe80::9", UINT32_MAX, "fe80::9%4294967295"))
        return 15;
    return 0;
}

static int policy(void)
{
    uint32_t index = loopback_index();
    if (!index || index > 9)
        return 90;
    char reverse[] = "ff01::1%0";
    reverse[8] = (char)('0' + index);
    if (!numeric("ff01::1%lo", "ff01::1", index, reverse))
        return 21;
    const char *invalid[] = {"fe80::1%", "fe80::1%lo%1", "fe80::1%4294967296",
                             "fe80::1%absent123", "fe80::1%.", "fe80::1%..",
                             "fe80::1%a:b", "fe80::1%a/b", "fe80::1%a b",
                             "fe80::1%abcdefghijklmnop", "2001:db8::7%lo",
                             "192.0.2.1%1", "::invalid%1"};
    struct addrinfo hints = {.ai_socktype = SOCK_STREAM, .ai_flags = AI_NUMERICHOST};
    for (size_t i = 0; i < sizeof invalid / sizeof *invalid; ++i) {
        struct addrinfo *output = (struct addrinfo *)(uintptr_t)0x57a;
        errno = EDOM;
        if (getaddrinfo(invalid[i], "19", &hints, &output) != EAI_NONAME || output || !preserved())
            return 30 + (int)i;
    }

    struct sockaddr_in6 address = {.sin6_family = AF_INET6, .sin6_scope_id = index, .sin6_port = htons(2049)};
    if (inet_pton(AF_INET6, "fe80::1", &address.sin6_addr) != 1)
        return 91;
    const struct sockaddr *input = (const void *)&address;
    char host[16], service[8];
    memset(host, 0x41, sizeof host);
    memset(service, 0x42, sizeof service);
    const char host_canary[] = "AAAAAAAAAAAAAAAA";
    const char service_canary[] = "BBBBBBBB";
    errno = EDOM;
    int flags = NI_NUMERICHOST | NI_NUMERICSERV;
    if (getnameinfo(input, sizeof address, host, 10, service, sizeof service, flags) != EAI_OVERFLOW ||
        memcmp(host, host_canary, sizeof host) || memcmp(service, service_canary, sizeof service) || !preserved())
        return 44;
    if (getnameinfo(input, sizeof address, host, sizeof host, service, 4, flags) != EAI_OVERFLOW ||
        memcmp(host, host_canary, sizeof host) || memcmp(service, service_canary, sizeof service) || !preserved())
        return 45;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 92;
    if (!strcmp(argv[1], "shared"))
        return shared();
    if (!strcmp(argv[1], "policy"))
        return policy();
    return 93;
}
