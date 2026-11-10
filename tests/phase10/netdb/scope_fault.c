#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <stdarg.h>
#include <stdint.h>
#include <string.h>
#include <sys/ioctl.h>

extern int __real_ioctl(int, unsigned long, ...);
extern unsigned __real___al_dns_config(void *, struct sockaddr *, void *);
static int enabled;
static unsigned get_index, get_name, configuration;

int __wrap_ioctl(int fd, unsigned long request, ...)
{
    va_list arguments;
    va_start(arguments, request);
    void *argument = va_arg(arguments, void *);
    va_end(arguments);
    if (enabled && request == 0x8933) {
        ++get_index;
        errno = EIO;
        return -1;
    }
    if (enabled && request == 0x8910) {
        ++get_name;
        errno = ENODEV;
        return -1;
    }
    return __real_ioctl(fd, request, argument);
}

unsigned __wrap___al_dns_config(void *context, struct sockaddr *address, void *search)
{
    if (enabled) {
        ++configuration;
        return 0;
    }
    return __real___al_dns_config(context, address, search);
}

int main(void)
{
    enabled = 1;
    struct addrinfo hints = {.ai_family = AF_INET6, .ai_socktype = SOCK_STREAM};
    struct addrinfo *result = (struct addrinfo *)(uintptr_t)0x48c;
    errno = EDOM;
    if (getaddrinfo("fe80::1%lo", "19", &hints, &result) != EAI_AGAIN || result ||
        errno != EDOM || get_index != 1 || get_name || configuration)
        return 11;
    const char *invalid[] = {"fe80::1%a/b", "fe80::1%", "fe80::1%4294967296", "2001:db8::1%lo"};
    for (size_t i = 0; i < sizeof invalid / sizeof *invalid; ++i) {
        result = (struct addrinfo *)(uintptr_t)0x48c;
        if (getaddrinfo(invalid[i], "19", &hints, &result) != EAI_NONAME || result ||
            errno != EDOM || get_index != 1 || get_name || configuration)
            return 12 + (int)i;
    }
    struct sockaddr_in6 address = {.sin6_family = AF_INET6, .sin6_scope_id = 117,
                                   .sin6_port = htons(19)};
    if (inet_pton(AF_INET6, "fe80::1", &address.sin6_addr) != 1)
        return 90;
    char host[32], service[8];
    if (getnameinfo((struct sockaddr *)&address, sizeof address, host, sizeof host,
                    service, sizeof service, NI_NUMERICHOST | NI_NUMERICSERV) ||
        strcmp(host, "fe80::1%117") || strcmp(service, "19") || get_name != 1 ||
        get_index != 1 || configuration || errno != EDOM)
        return 16;
    return 0;
}
