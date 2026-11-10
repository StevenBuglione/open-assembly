#include <errno.h>
#include <netdb.h>
#include <stdint.h>

extern int __al_gai_addrconfig(void);

int main(void)
{
    struct addrinfo hints = {.ai_family = AF_INET, .ai_flags = AI_ADDRCONFIG | AI_NUMERICHOST};
    struct addrinfo *result = (struct addrinfo *)(uintptr_t)0x19b;
    errno = EDOM;
    if (__al_gai_addrconfig() != 0 || errno != EDOM)
        return 11;
    if (getaddrinfo("127.0.0.1", "17", &hints, &result) != EAI_NONAME || result || errno != EDOM)
        return 12;
    hints.ai_family = AF_INET6;
    result = (struct addrinfo *)(uintptr_t)0x19b;
    if (getaddrinfo("::1", "17", &hints, &result) != EAI_NONAME || result || errno != EDOM)
        return 13;
    hints.ai_flags = AI_NUMERICHOST;
    if (getaddrinfo("::1", "17", &hints, &result) || !result ||
        result->ai_family != AF_INET6 || errno != EDOM)
        return 14;
    freeaddrinfo(result);
    return 0;
}
