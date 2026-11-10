#include <arpa/inet.h>
#include <errno.h>
#include <poll.h>
#include <stdint.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/socket.h>
#include <unistd.h>

enum { WAIT_MS = 1000 };

static int readable(int queue, int descriptor, uint64_t identity)
{
    struct pollfd watch = {.fd = descriptor, .events = POLLIN};
    struct epoll_event ready = {0};
    return poll(&watch, 1, WAIT_MS) == 1 && (watch.revents & POLLIN) &&
           !(watch.revents & (POLLERR | POLLNVAL)) &&
           epoll_wait(queue, &ready, 1, WAIT_MS) == 1 &&
           (ready.events & EPOLLIN) && ready.data.u64 == identity;
}

static int drained(int queue, int descriptor)
{
    struct pollfd watch = {.fd = descriptor, .events = POLLIN};
    struct epoll_event ready = {0};
    return poll(&watch, 1, 0) == 0 && !watch.revents && epoll_wait(queue, &ready, 1, 0) == 0;
}

int main(void)
{
    int listener = socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0);
    int queue = epoll_create1(EPOLL_CLOEXEC);
    if (listener < 0 || queue < 0)
        return 11;
    struct sockaddr_in address = {.sin_family = AF_INET, .sin_addr.s_addr = htonl(0x7f000001)};
    struct sockaddr *name = (struct sockaddr *)&address;
    if (bind(listener, name, sizeof address) || listen(listener, 2))
        return 12;
    socklen_t length = sizeof address;
    if (getsockname(listener, name, &length) || length != sizeof address || !address.sin_port ||
        address.sin_addr.s_addr != htonl(0x7f000001))
        return 13;

    const uint64_t accept_tag = UINT64_C(0x6545f7a46a513c11);
    const uint64_t read_tag = UINT64_C(0x419ac7feef5270b2);
    struct epoll_event watch = {.events = EPOLLIN, .data.u64 = accept_tag};
    if (epoll_ctl(queue, EPOLL_CTL_ADD, listener, &watch) || !drained(queue, listener))
        return 14;
    int client = socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (client < 0 || connect(client, name, sizeof address) || !readable(queue, listener, accept_tag))
        return 15;
    int server = accept4(listener, NULL, NULL, SOCK_CLOEXEC | SOCK_NONBLOCK);
    if (server < 0 || epoll_ctl(queue, EPOLL_CTL_DEL, listener, NULL) || !drained(queue, listener))
        return 16;

    watch.data.u64 = read_tag;
    if (epoll_ctl(queue, EPOLL_CTL_ADD, server, &watch) || !drained(queue, server))
        return 17;
    unsigned char data[4] = {0xa5, 0xa5, 0xa5, 0xa5};
    if (recv(server, data, sizeof data, 0) != -1 || (errno != EAGAIN && errno != EWOULDBLOCK) ||
        data[0] != 0xa5)
        return 18;

    static const unsigned char payload[] = {0x19, 0, 0x80};
    if (send(client, payload, sizeof payload, 0) != sizeof payload || !readable(queue, server, read_tag))
        return 19;
    size_t offset = 0;
    while (offset < sizeof payload) {
        ssize_t count = recv(server, data + offset, sizeof payload - offset, 0);
        if (count < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            if (!readable(queue, server, read_tag))
                return 20;
            continue;
        }
        if (count <= 0)
            return 21;
        offset += (size_t)count;
    }
    if (memcmp(data, payload, sizeof payload) || data[sizeof payload] != 0xa5 || !drained(queue, server))
        return 22;
    if (shutdown(client, SHUT_WR) || !readable(queue, server, read_tag) ||
        recv(server, data, sizeof data, 0) != 0)
        return 23;
    if (epoll_ctl(queue, EPOLL_CTL_DEL, server, NULL) ||
        epoll_wait(queue, &watch, 1, 0) != 0 ||
        close(server) || close(client) || close(listener) || close(queue))
        return 24;
    return 0;
}
