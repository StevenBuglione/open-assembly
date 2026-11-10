#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <signal.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

_Static_assert(sizeof(socklen_t) == 4 && sizeof(sa_family_t) == 2, "Linux socket field widths");
_Static_assert(sizeof(struct sockaddr) == 16 && sizeof(struct sockaddr_storage) == 128 &&
               _Alignof(struct sockaddr_storage) == 8, "Linux generic sockaddr layout");
_Static_assert(sizeof(struct sockaddr_in) == 16 && sizeof(struct sockaddr_in6) == 28 &&
               sizeof(struct sockaddr_un) == 110, "Linux sockaddr layouts");
_Static_assert(sizeof(struct msghdr) == 56 && offsetof(struct msghdr, msg_iov) == 16 &&
               offsetof(struct msghdr, msg_control) == 32 && offsetof(struct msghdr, msg_flags) == 48,
               "Linux LP64 msghdr");
_Static_assert(sizeof(struct iovec) == 16 && sizeof(struct cmsghdr) == 16 &&
               offsetof(struct cmsghdr, cmsg_level) == 8 && offsetof(struct cmsghdr, cmsg_type) == 12,
               "Linux LP64 message records");

static struct sockaddr_in loopback(void)
{
    return (struct sockaddr_in){.sin_family = AF_INET, .sin_addr = {.s_addr = 0x0100007f}};
}

static int pair_stream(void)
{
    int ends[2] = {-9, -9};
    errno = EDOM;
    if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0, ends) ||
        ends[0] < 0 || ends[1] < 0 || ends[0] == ends[1] || errno != EDOM)
        return 11;
    for (size_t i = 0; i < 2; ++i) {
        if (!(fcntl(ends[i], F_GETFL) & O_NONBLOCK) || fcntl(ends[i], F_GETFD) != FD_CLOEXEC)
            return 12;
    }
    char got[5] = {'#', '#', '#', '#', '#'};
    if (recv(ends[0], got, sizeof got, 0) != -1 || errno != EAGAIN || got[0] != '#')
        return 13;
    errno = EDOM;
    if (send(ends[1], "abc", 3, MSG_NOSIGNAL) != 3 ||
        recv(ends[0], got, 1, MSG_PEEK) != 1 || got[0] != 'a' || got[1] != '#' ||
        recv(ends[0], got, sizeof got, 0) != 3 || memcmp(got, "abc##", sizeof got) ||
        errno != EDOM)
        return 14;
    if (shutdown(ends[1], SHUT_WR) || recv(ends[0], got, 1, 0) || errno != EDOM ||
        send(ends[0], "z", 1, MSG_NOSIGNAL) != 1 || recv(ends[1], got, 1, 0) != 1 ||
        got[0] != 'z' || errno != EDOM)
        return 15;
    return close(ends[0]) || close(ends[1]) ? 16 : 0;
}

static int tcp(int flags)
{
    errno = EDOM;
    int listening = socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0);
    int client = socket(AF_INET, SOCK_STREAM, 0);
    if (listening < 0 || client < 0 || errno != EDOM ||
        fcntl(listening, F_GETFD) != FD_CLOEXEC)
        return 21;
    struct sockaddr_in address = loopback();
    if (bind(listening, (const struct sockaddr *)&address, sizeof address) ||
        listen(listening, 4) || errno != EDOM)
        return 22;
    socklen_t size = sizeof address;
    if (getsockname(listening, (struct sockaddr *)&address, &size) || size != sizeof address ||
        address.sin_family != AF_INET || address.sin_addr.s_addr != 0x0100007f ||
        !address.sin_port || errno != EDOM)
        return 23;
    if (connect(client, (const struct sockaddr *)&address, size) || errno != EDOM)
        return 24;
    struct sockaddr_in client_local, client_peer;
    size = sizeof client_local;
    if (getsockname(client, (struct sockaddr *)&client_local, &size) || size != sizeof client_local)
        return 25;
    size = sizeof client_peer;
    if (getpeername(client, (struct sockaddr *)&client_peer, &size) || size != sizeof client_peer ||
        client_peer.sin_port != address.sin_port || client_peer.sin_addr.s_addr != address.sin_addr.s_addr ||
        errno != EDOM)
        return 26;
    struct sockaddr_in peer;
    size = sizeof peer;
    int accepted = flags ? accept4(listening, (struct sockaddr *)&peer, &size,
                                  SOCK_NONBLOCK | SOCK_CLOEXEC)
                         : accept(listening, (struct sockaddr *)&peer, &size);
    if (accepted < 0 || size != sizeof peer || peer.sin_family != AF_INET ||
        peer.sin_port != client_local.sin_port || peer.sin_addr.s_addr != client_local.sin_addr.s_addr ||
        errno != EDOM)
        return 27;
    int selected = fcntl(accepted, F_GETFL);
    if (selected < 0 || (selected & O_NONBLOCK) != (flags ? O_NONBLOCK : 0) ||
        fcntl(accepted, F_GETFD) != (flags ? FD_CLOEXEC : 0))
        return 28;
    struct sockaddr_in truncated;
    memset(&truncated, 0xa5, sizeof truncated);
    size = sizeof truncated.sin_family;
    if (getpeername(accepted, (struct sockaddr *)&truncated, &size) ||
        size != sizeof truncated || truncated.sin_family != AF_INET || errno != EDOM)
        return 29;
    const unsigned char *bytes = (const unsigned char *)&truncated;
    for (size_t i = sizeof truncated.sin_family; i < sizeof truncated; ++i) {
        if (bytes[i] != 0xa5)
            return 30;
    }
    return close(accepted) || close(client) || close(listening) ? 31 : 0;
}

static int udp(void)
{
    int sender = socket(AF_INET, SOCK_DGRAM, 0);
    int receiver = socket(AF_INET, SOCK_DGRAM, 0);
    if (sender < 0 || receiver < 0)
        return 40;
    struct sockaddr_in target = loopback(), source;
    socklen_t size = sizeof target;
    errno = EDOM;
    if (bind(receiver, (const struct sockaddr *)&target, size) ||
        getsockname(receiver, (struct sockaddr *)&target, &size) || !target.sin_port ||
        errno != EDOM)
        return 41;
    char bytes[6] = {'#', '#', '#', '#', '#', '#'};
    if (sendto(sender, "abcdefgh", 8, 0, (const struct sockaddr *)&target, size) != 8 ||
        errno != EDOM)
        return 42;
    size = sizeof source;
    if (recvfrom(receiver, bytes, 4, MSG_TRUNC, (struct sockaddr *)&source, &size) != 8 ||
        size != sizeof source || source.sin_family != AF_INET || !source.sin_port ||
        source.sin_addr.s_addr != target.sin_addr.s_addr || memcmp(bytes, "abcd##", sizeof bytes) ||
        errno != EDOM)
        return 43;
    if (sendto(sender, bytes, 0, 0, (const struct sockaddr *)&target, sizeof target) != 0 ||
        recvfrom(receiver, bytes, sizeof bytes, 0, NULL, NULL) != 0 ||
        memcmp(bytes, "abcd##", sizeof bytes) || errno != EDOM)
        return 44;
    if (recvfrom(receiver, bytes, sizeof bytes, MSG_DONTWAIT, NULL, NULL) != -1 ||
        errno != EAGAIN)
        return 45;
    return close(sender) || close(receiver) ? 46 : 0;
}

static int options(void)
{
    errno = EDOM;
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    int value = -1;
    socklen_t size = sizeof value;
    if (fd < 0 || getsockopt(fd, SOL_SOCKET, SO_TYPE, &value, &size) ||
        value != SOCK_STREAM || size != sizeof value || errno != EDOM)
        return 50;
    const int enabled = 1;
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof enabled) ||
        getsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &value, &size) ||
        value != enabled || errno != EDOM)
        return 51;
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &enabled, 1) != -1 || errno != EINVAL)
        return 52;
    errno = EDOM;
    value = -1;
    if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &value, &size) || value || errno != EDOM)
        return 53;
    return close(fd) ? 54 : 0;
}

static int ancillary(void)
{
    int ends[2], fds[2];
    if (socketpair(AF_UNIX, SOCK_DGRAM, 0, ends) || pipe(fds))
        return 60;
    char first[] = "AB", second[] = "cde";
    struct iovec parts[2] = {{first, 2}, {second, 3}};
    _Alignas(struct cmsghdr) unsigned char control[CMSG_SPACE(sizeof(int))] = {0};
    struct msghdr message = {.msg_iov = parts, .msg_iovlen = 2, .msg_control = control,
                             .msg_controllen = sizeof control};
    struct cmsghdr *header = CMSG_FIRSTHDR(&message);
    if (!header || CMSG_LEN(sizeof(int)) != 20 || sizeof control != 24)
        return 61;
    header->cmsg_len = CMSG_LEN(sizeof(int));
    header->cmsg_level = SOL_SOCKET;
    header->cmsg_type = SCM_RIGHTS;
    memcpy(CMSG_DATA(header), &fds[0], sizeof fds[0]);
    errno = EDOM;
    if (sendmsg(ends[0], &message, MSG_NOSIGNAL) != 5 || errno != EDOM || close(fds[0]))
        return 62;
    char x[3] = {'#', '#', '#'}, y[5] = {'#', '#', '#', '#', '#'};
    struct iovec result[2] = {{x, 1}, {y, 4}};
    memset(control, 0, sizeof control);
    message.msg_iov = result;
    if (recvmsg(ends[1], &message, MSG_CMSG_CLOEXEC) != 5 ||
        (message.msg_flags & (MSG_TRUNC | MSG_CTRUNC)) ||
        memcmp(x, "A##", sizeof x) || memcmp(y, "Bcde#", sizeof y) || errno != EDOM)
        return 63;
    header = CMSG_FIRSTHDR(&message);
    struct cmsghdr *following = header ? CMSG_NXTHDR(&message, header) : NULL;
    if (!header || header->cmsg_len != CMSG_LEN(sizeof(int)) || header->cmsg_level != SOL_SOCKET ||
        header->cmsg_type != SCM_RIGHTS || following != NULL)
        return 64;
    int received = -1;
    memcpy(&received, CMSG_DATA(header), sizeof received);
    char marker = '#';
    if (received < 0 || fcntl(received, F_GETFD) != FD_CLOEXEC ||
        write(fds[1], "V", 1) != 1 || read(received, &marker, 1) != 1 || marker != 'V')
        return 65;
    return close(received) || close(fds[1]) || close(ends[0]) || close(ends[1]) ? 66 : 0;
}

#ifndef OA_PHASE10_HOST
static int ancillary_bounds(void)
{
    _Alignas(struct cmsghdr) unsigned char data[48] = {0};
    struct msghdr message = {.msg_control = data, .msg_controllen = sizeof data};
    struct cmsghdr *first = CMSG_FIRSTHDR(&message);
    struct cmsghdr *second = (struct cmsghdr *)(data + 24);
    first->cmsg_len = 20;
    second->cmsg_len = 16;
    if (CMSG_NXTHDR(&message, first) != second || CMSG_NXTHDR(&message, second))
        return 71;
    first->cmsg_len = 15;
    if (CMSG_NXTHDR(&message, first))
        return 72;
    first->cmsg_len = SIZE_MAX;
    if (CMSG_NXTHDR(&message, first))
        return 73;
    first->cmsg_len = 20;
    message.msg_controllen = 39;
    if (CMSG_NXTHDR(&message, first) || CMSG_NXTHDR(&message, second))
        return 74;
    message.msg_controllen = 15;
    return CMSG_FIRSTHDR(&message) ? 75 : 0;
}
#endif

static volatile sig_atomic_t broken_pipes;

static void broken_pipe(int signum)
{
    if (signum == SIGPIPE)
        ++broken_pipes;
}

static int sigpipe_case(void)
{
    struct sigaction action = {.sa_handler = broken_pipe};
    int ends[2];
    if (sigemptyset(&action.sa_mask) || sigaction(SIGPIPE, &action, NULL) ||
        socketpair(AF_UNIX, SOCK_STREAM, 0, ends) || close(ends[1]))
        return 80;
    errno = EDOM;
    if (send(ends[0], "x", 1, MSG_NOSIGNAL) != -1 || errno != EPIPE || broken_pipes != 0)
        return 81;
    errno = EDOM;
    if (send(ends[0], "x", 1, 0) != -1 || errno != EPIPE || broken_pipes != 1)
        return 82;
    return close(ends[0]) ? 83 : 0;
}

static int short_transfer(void)
{
    int ends[2], buffer_size = 4096;
    static unsigned char sent[131072], got[131072];
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, ends) ||
        setsockopt(ends[0], SOL_SOCKET, SO_SNDBUF, &buffer_size, sizeof buffer_size))
        return 84;
    for (size_t i = 0; i < sizeof sent; ++i)
        sent[i] = (unsigned char)(i * 13 + 9);
    errno = EDOM;
    ssize_t count = send(ends[0], sent, sizeof sent, MSG_DONTWAIT | MSG_NOSIGNAL);
    if (count <= 0 || count >= (ssize_t)sizeof sent || errno != EDOM)
        return 85;
    size_t offset = 0;
    while (offset < (size_t)count) {
        ssize_t part = recv(ends[1], got + offset, (size_t)count - offset, MSG_DONTWAIT);
        if (part <= 0 || errno != EDOM)
            return 86;
        offset += (size_t)part;
    }
    if (memcmp(got, sent, offset))
        return 87;
    return close(ends[0]) || close(ends[1]) ? 88 : 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    const char *mode = argv[1];
    if (!strcmp(mode, "pair"))
        return pair_stream();
    if (!strcmp(mode, "tcp") || !strcmp(mode, "accept4"))
        return tcp(!strcmp(mode, "accept4"));
    if (!strcmp(mode, "udp"))
        return udp();
    if (!strcmp(mode, "options"))
        return options();
    if (!strcmp(mode, "ancillary"))
        return ancillary();
#ifndef OA_PHASE10_HOST
    if (!strcmp(mode, "ancillary-bounds"))
        return ancillary_bounds();
#endif
    if (!strcmp(mode, "sigpipe"))
        return sigpipe_case();
    if (!strcmp(mode, "short"))
        return short_transfer();
    return 91;
}
