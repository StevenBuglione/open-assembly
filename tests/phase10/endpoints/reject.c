#define _GNU_SOURCE
#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/socket.h>
#include <time.h>

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    const char *name = argv[1];
    struct sockaddr address = {0};
    socklen_t length = sizeof address;
    struct epoll_event event = {0};
    char byte = '#';
    struct iovec vector = {&byte, 1};
    struct msghdr message = {.msg_iov = &vector, .msg_iovlen = 1};
    int pair[2] = {-19, -20};
    long result;
    int expected = EBADF;
    errno = EDOM;
    if (!strcmp(name, "socket")) {
        expected = EINVAL;
        result = socket(AF_UNIX, 0x7fffffff, 0);
    } else if (!strcmp(name, "socketpair")) {
        expected = EINVAL;
        result = socketpair(AF_UNIX, 0x7fffffff, 0, pair);
    } else if (!strcmp(name, "bind")) {
        result = bind(-1, &address, length);
    } else if (!strcmp(name, "connect")) {
        result = connect(-1, &address, length);
    } else if (!strcmp(name, "listen")) {
        result = listen(-1, 1);
    } else if (!strcmp(name, "accept")) {
        result = accept(-1, &address, &length);
    } else if (!strcmp(name, "accept4")) {
        result = accept4(-1, &address, &length, SOCK_CLOEXEC);
    } else if (!strcmp(name, "getsockname")) {
        result = getsockname(-1, &address, &length);
    } else if (!strcmp(name, "getpeername")) {
        result = getpeername(-1, &address, &length);
    } else if (!strcmp(name, "setsockopt")) {
        const int value = 1;
        result = setsockopt(-1, SOL_SOCKET, SO_REUSEADDR, &value, sizeof value);
    } else if (!strcmp(name, "getsockopt")) {
        int value;
        length = sizeof value;
        result = getsockopt(-1, SOL_SOCKET, SO_TYPE, &value, &length);
    } else if (!strcmp(name, "shutdown")) {
        result = shutdown(-1, SHUT_WR);
    } else if (!strcmp(name, "send")) {
        result = send(-1, &byte, 1, MSG_NOSIGNAL);
    } else if (!strcmp(name, "recv")) {
        result = recv(-1, &byte, 1, MSG_DONTWAIT);
    } else if (!strcmp(name, "sendto")) {
        result = sendto(-1, &byte, 1, 0, &address, length);
    } else if (!strcmp(name, "recvfrom")) {
        result = recvfrom(-1, &byte, 1, MSG_DONTWAIT, &address, &length);
    } else if (!strcmp(name, "sendmsg")) {
        result = sendmsg(-1, &message, MSG_NOSIGNAL);
    } else if (!strcmp(name, "recvmsg")) {
        result = recvmsg(-1, &message, MSG_DONTWAIT);
    } else if (!strcmp(name, "poll")) {
        struct pollfd fd = {0x7fffffff, POLLIN, -1};
        result = poll(&fd, 1, 0);
        if (result != 1)
            return 11;
        return fd.revents == POLLNVAL && errno == EDOM ? 0 : 12;
    } else if (!strcmp(name, "ppoll")) {
        expected = EINVAL;
        const struct timespec invalid = {0, 1000000000};
        result = ppoll(NULL, 0, &invalid, NULL);
    } else if (!strcmp(name, "epoll_create")) {
        expected = EINVAL;
        result = epoll_create(0);
    } else if (!strcmp(name, "epoll_create1")) {
        expected = EINVAL;
        result = epoll_create1(1);
    } else if (!strcmp(name, "epoll_ctl")) {
        result = epoll_ctl(-1, EPOLL_CTL_ADD, 0, &event);
    } else if (!strcmp(name, "epoll_wait")) {
        result = epoll_wait(-1, &event, 1, 0);
    } else if (!strcmp(name, "epoll_pwait")) {
        result = epoll_pwait(-1, &event, 1, 0, NULL);
    } else {
        return 91;
    }
    if (result != -1)
        return 11;
    if (errno != expected)
        return 12;
    if (byte != '#' || pair[0] != -19 || pair[1] != -20)
        return 13;
    return 0;
}
