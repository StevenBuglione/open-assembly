#include "contract.h"
#include <netinet/in.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
    if (argc != 3)
        return 90;
    char *end;
    long port = strtol(argv[1], &end, 10);
    if (*end || port <= 0 || port > 65535)
        return 91;
    struct sockaddr_in server = {.sin_family = AF_INET};
    unsigned char *address = (void *)&server.sin_addr, *number = (void *)&server.sin_port;
    const unsigned char loopback[4] = {127, 0, 0, 1};
    memcpy(address, loopback, sizeof loopback);
    number[0] = (unsigned char)(port / 256);
    number[1] = (unsigned char)(port % 256);
    struct answer answer;
    memset(&answer, 0xa5, sizeof answer);
    errno = EDOM;
    unsigned type = !strcmp(argv[2], "AAAA") ? 28 : 1;
    int status = __al_dns_query((const struct sockaddr *)&server, sizeof server, "Query.Example",
                                type, &answer);
    return errno == EDOM && emit_answer(status, &answer) ? 0 : 92;
}
