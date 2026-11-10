#include <errno.h>
#include <poll.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/epoll.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

extern unsigned phase2_abi_probe(uintptr_t, const uint64_t[6]);

#define ADDRESS(value) ((uint64_t)(uintptr_t)(value))
#define INTARG(value) (UINT64_C(0xa135ef7000000000) | (uint32_t)(value))
#define CALL(function, ...) phase2_abi_probe((uintptr_t)function, (const uint64_t[6]){__VA_ARGS__})
#define ERROR(function, expected, ...) do { \
    errno = EDOM; \
    if (CALL(function, __VA_ARGS__) || errno != (expected)) \
        return stage; \
    ++stage; \
} while (0)

int main(void)
{
    int stage = 10;
    const uint64_t bad = INTARG(-1);
    struct sockaddr address = {0};
    socklen_t length = sizeof address;
    struct epoll_event event = {0};
    int value = 1, pair[] = {-1, -1};
    char byte = '#';
    struct iovec vector = {&byte, 1};
    struct msghdr message = {.msg_iov = &vector, .msg_iovlen = 1};
    ERROR(socket, EINVAL, INTARG(AF_UNIX), INTARG(0x7fffffff), INTARG(0));
    errno = EDOM;
    if (CALL(socketpair, INTARG(AF_UNIX), INTARG(SOCK_STREAM), INTARG(0), ADDRESS(pair)) ||
        pair[0] < 0 || pair[1] < 0 || pair[0] == pair[1] || errno != EDOM ||
        close(pair[0]) || close(pair[1]))
        return stage;
    ++stage;
    ERROR(bind, EBADF, bad, ADDRESS(&address), INTARG(sizeof address));
    ERROR(connect, EBADF, bad, ADDRESS(&address), INTARG(sizeof address));
    ERROR(listen, EBADF, bad, INTARG(1));
    ERROR(accept, EBADF, bad, ADDRESS(&address), ADDRESS(&length));
    ERROR(accept4, EBADF, bad, ADDRESS(&address), ADDRESS(&length), INTARG(SOCK_CLOEXEC));
    ERROR(getsockname, EBADF, bad, ADDRESS(&address), ADDRESS(&length));
    ERROR(getpeername, EBADF, bad, ADDRESS(&address), ADDRESS(&length));
    ERROR(setsockopt, EBADF, bad, INTARG(SOL_SOCKET), INTARG(SO_REUSEADDR), ADDRESS(&value), INTARG(4));
    ERROR(getsockopt, EBADF, bad, INTARG(SOL_SOCKET), INTARG(SO_TYPE), ADDRESS(&value), ADDRESS(&length));
    ERROR(shutdown, EBADF, bad, INTARG(SHUT_WR));
    ERROR(send, EBADF, bad, ADDRESS(&byte), 1, INTARG(MSG_NOSIGNAL));
    ERROR(recv, EBADF, bad, ADDRESS(&byte), 1, INTARG(MSG_DONTWAIT));
    ERROR(sendto, EBADF, bad, ADDRESS(&byte), 1, INTARG(0), ADDRESS(&address), INTARG(sizeof address));
    ERROR(recvfrom, EBADF, bad, ADDRESS(&byte), 1, INTARG(MSG_DONTWAIT), ADDRESS(&address), ADDRESS(&length));
    ERROR(sendmsg, EBADF, bad, ADDRESS(&message), INTARG(MSG_NOSIGNAL));
    ERROR(recvmsg, EBADF, bad, ADDRESS(&message), INTARG(MSG_DONTWAIT));

    errno = EDOM;
    struct pollfd descriptor = {0x7fffffff, POLLIN, -1};
    if (CALL(poll, ADDRESS(&descriptor), 1, INTARG(0)) || descriptor.revents != POLLNVAL || errno != EDOM)
        return stage;
    ++stage;
    const struct timespec invalid = {0, 1000000000};
    ERROR(ppoll, EINVAL, 0, 0, ADDRESS(&invalid), 0);
    ERROR(epoll_create, EINVAL, INTARG(0));
    ERROR(epoll_create1, EINVAL, INTARG(1));
    ERROR(epoll_ctl, EBADF, bad, INTARG(EPOLL_CTL_ADD), INTARG(0), ADDRESS(&event));
    ERROR(epoll_wait, EBADF, bad, ADDRESS(&event), INTARG(1), INTARG(0));
    ERROR(epoll_pwait, EBADF, bad, ADDRESS(&event), INTARG(1), INTARG(0), 0);
    return 0;
}
