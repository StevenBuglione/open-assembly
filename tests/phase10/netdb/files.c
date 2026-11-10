#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>

extern FILE *__real_fopen(const char *, const char *);
static int active, hosts, services;

FILE *__wrap_fopen(const char *path, const char *mode)
{
    if (active && !strcmp(path, "/etc/hosts")) {
        ++hosts;
        return __real_fopen("hosts", mode);
    }
    if (active && !strcmp(path, "/etc/services")) {
        ++services;
        return __real_fopen("services", mode);
    }
    return __real_fopen(path, mode);
}

static int write_fixtures(int overlong, int bulk)
{
    FILE *file = __real_fopen("hosts", "w");
    if (!file)
        return 0;
    int ok = 1;
    if (bulk) {
        for (unsigned i = 1; i <= 40 && ok; ++i)
            ok = fprintf(file, "198.51.100.%u bulk\n", i) > 0;
    } else {
        if (overlong) {
            char padding[4096];
            memset(padding, 'x', sizeof padding);
            ok = fputs("203.0.113.44 fake AliasOne ", file) >= 0 &&
                 fwrite(padding, 1, sizeof padding, file) == sizeof padding && fputc('\n', file) != EOF;
        }
        ok = ok && fputs("192.0.2.32 named.example AliasOne AliasTwo # real match\n"
                        "2001:db8::32 named6.example AliasSix\n", file) >= 0;
    }
    if (fclose(file) || !ok)
        return 0;
    if (bulk)
        return 1;

    file = __real_fopen("services", "w");
    if (!file)
        return 0;
    ok = fputs("invalid 65536/tcp alt-service\n"
               "fixture 5137/tcp alt-service\n"
               "fixture 6137/udp alt-service\n"
               "reverse-tcp 4242/tcp\n"
               "reverse-udp 4242/udp\n", file) >= 0;
    return fclose(file) == 0 && ok;
}

static unsigned port(const struct sockaddr_in *address)
{
    const unsigned char *bytes = (const void *)&address->sin_port;
    return 256u * bytes[0] + bytes[1];
}

static int forward(void)
{
    const struct addrinfo hints = {.ai_family = AF_INET, .ai_flags = AI_CANONNAME};
    struct addrinfo *list = NULL;
    errno = EDOM;
    if (getaddrinfo("ALIASONE.", "alt-service", &hints, &list) || !list || !list->ai_next ||
        list->ai_next->ai_next || !hosts || !services || errno != EDOM)
        return 11;
    const unsigned char expected[4] = {192, 0, 2, 32};
    const struct addrinfo *entry = list;
    for (int i = 0; i < 2; ++i) {
        if (entry->ai_family != AF_INET || !entry->ai_addr ||
            entry->ai_addrlen != sizeof(struct sockaddr_in) ||
            entry->ai_socktype != (i ? SOCK_DGRAM : SOCK_STREAM) ||
            entry->ai_protocol != (i ? IPPROTO_UDP : IPPROTO_TCP))
            return 12;
        const struct sockaddr_in *address = (const void *)entry->ai_addr;
        if (address->sin_family != AF_INET || memcmp(&address->sin_addr, expected, sizeof expected) ||
            port(address) != (i ? 6137u : 5137u))
            return 13;
        if (i ? entry->ai_canonname != NULL
              : !entry->ai_canonname || strcmp(entry->ai_canonname, "named.example"))
            return 14;
        entry = entry->ai_next;
    }
    freeaddrinfo(list);
    if (errno != EDOM)
        return 15;
    int prior_services = services;
    struct addrinfo sentinel;
    list = &sentinel;
    if (getaddrinfo("192.0.2.32", "65536", &hints, &list) != EAI_SERVICE || list ||
        services <= prior_services || errno != EDOM)
        return 16;
    return 0;
}

static int many(void)
{
    const struct addrinfo hints = {.ai_family = AF_INET, .ai_socktype = SOCK_STREAM};
    struct addrinfo *list = NULL;
    errno = EDOM;
    if (getaddrinfo("bulk", "55", &hints, &list) || !list || errno != EDOM)
        return 17;
    const struct addrinfo *entry = list;
    for (unsigned i = 1; i <= 32; ++i) {
        if (!entry || entry->ai_family != AF_INET || !entry->ai_addr ||
            entry->ai_addrlen != sizeof(struct sockaddr_in))
            return 18;
        const struct sockaddr_in *address = (const void *)entry->ai_addr;
        const unsigned char *bytes = (const void *)&address->sin_addr;
        if (bytes[0] != 198 || bytes[1] != 51 || bytes[2] != 100 || bytes[3] != i ||
            port(address) != 55)
            return 19;
        entry = entry->ai_next;
    }
    int truncated = entry == NULL;
    freeaddrinfo(list);
    return truncated && errno == EDOM ? 0 : 20;
}

static int reverse(void)
{
    struct sockaddr_in address = {.sin_family = AF_INET};
    const unsigned char bytes[] = {192, 0, 2, 32};
    memcpy(&address.sin_addr, bytes, sizeof bytes);
    unsigned char *value = (void *)&address.sin_port;
    value[0] = 4242 / 256;
    value[1] = 4242 % 256;
    char node[64], service[32];
    errno = EDOM;
    if (getnameinfo((const struct sockaddr *)&address, sizeof address, node, sizeof node,
                    service, sizeof service, 0) ||
        strcmp(node, "named.example") || strcmp(service, "reverse-tcp") ||
        !hosts || !services || errno != EDOM)
        return 21;
    if (getnameinfo((const struct sockaddr *)&address, sizeof address, node, sizeof node,
                    service, sizeof service, NI_NOFQDN | NI_DGRAM) ||
        strcmp(node, "named") || strcmp(service, "reverse-udp") || errno != EDOM)
        return 22;

    int prior_hosts = hosts, prior_services = services;
    if (getnameinfo((const struct sockaddr *)&address, sizeof address, node, sizeof node,
                    service, sizeof service, NI_NUMERICHOST | NI_NUMERICSERV) ||
        strcmp(node, "192.0.2.32") || strcmp(service, "4242") || errno != EDOM ||
        hosts != prior_hosts || services != prior_services)
        return 23;
    memset(node, '#', sizeof node);
    memset(service, '$', sizeof service);
    ((unsigned char *)&address.sin_addr)[3] = 99;
    if (getnameinfo((const struct sockaddr *)&address, sizeof address, node, sizeof node,
                    service, sizeof service, NI_NAMEREQD) != EAI_NONAME ||
        node[0] != '#' || service[0] != '$' || errno != EDOM)
        return 24;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    int is_forward = !strcmp(argv[1], "forward");
    int is_many = !strcmp(argv[1], "many");
    int is_reverse = !strcmp(argv[1], "reverse");
    if (!is_forward && !is_many && !is_reverse)
        return 91;
    if (!write_fixtures(is_forward, is_many))
        return 92;
    active = 1;
    if (is_forward)
        return forward();
    if (is_many)
        return many();
    return reverse();
}
