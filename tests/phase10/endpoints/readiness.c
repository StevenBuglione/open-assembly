#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <sys/epoll.h>
#include <time.h>
#include <unistd.h>

_Static_assert(sizeof(nfds_t) == 8 && sizeof(struct pollfd) == 8 &&
               offsetof(struct pollfd, revents) == 6, "Linux poll ABI");
_Static_assert(sizeof(struct epoll_event) == 12 &&
               offsetof(struct epoll_event, data) == 4, "Linux packed epoll ABI");

static int poll_ready(void)
{
    int fds[2];
    if (pipe(fds) || write(fds[1], "p", 1) != 1)
        return 10;
    struct pollfd entries[] = {{-1, POLLIN, -1}, {fds[0], POLLIN, -1},
                               {0x7fffffff, POLLIN, -1}};
    errno = EDOM;
    if (poll(entries, 3, 0) != 2 || entries[0].revents != 0 ||
        entries[1].revents != POLLIN || entries[2].revents != POLLNVAL ||
        entries[1].events != POLLIN || entries[1].fd != fds[0] || errno != EDOM)
        return 11;
    char marker = '#';
    if (read(fds[0], &marker, 1) != 1 || marker != 'p')
        return 12;
    struct timespec timeout = {0, 340000};
    if (ppoll(entries, 2, &timeout, NULL) != 0 || entries[0].revents ||
        entries[1].revents || timeout.tv_sec != 0 || timeout.tv_nsec != 340000 ||
        errno != EDOM)
        return 13;
    if (poll(NULL, 0, 0) || errno != EDOM)
        return 14;
    return close(fds[0]) || close(fds[1]) ? 15 : 0;
}

#ifndef OA_PHASE10_HOST
static int large_count(void)
{
    struct pollfd fd = {-1, POLLIN, -1};
    const nfds_t count = UINT64_C(1) << 32;
    errno = EDOM;
    if (poll(&fd, count, 0) != -1 || errno != EINVAL || fd.revents != -1)
        return 20;
    errno = EDOM;
    const struct timespec time = {0, 1000};
    if (ppoll(&fd, count + 1, &time, NULL) != -1 || errno != EINVAL ||
        fd.revents != -1 || time.tv_nsec != 1000)
        return 21;
    return 0;
}
#endif

static int epoll_ready(int use_create1)
{
    errno = EDOM;
    int epfd = use_create1 ? epoll_create1(EPOLL_CLOEXEC) : epoll_create(1);
    if (epfd < 0 || fcntl(epfd, F_GETFD) != (use_create1 ? FD_CLOEXEC : 0) || errno != EDOM)
        return 30;
    int fds[2][2];
    const uint64_t tags[2] = {UINT64_C(0xfedcba9876543210), UINT64_C(0x89abcdef01234567)};
    for (int i = 0; i < 2; ++i) {
        struct epoll_event input = {.events = EPOLLIN, .data.u64 = tags[i]};
        if (pipe(fds[i]) || epoll_ctl(epfd, EPOLL_CTL_ADD, fds[i][0], &input) ||
            input.events != EPOLLIN || input.data.u64 != tags[i] ||
            write(fds[i][1], "X", 1) != 1 || errno != EDOM)
            return 31;
    }
    struct epoll_event duplicate = {.events = EPOLLIN};
    if (epoll_ctl(epfd, EPOLL_CTL_ADD, fds[0][0], &duplicate) != -1 || errno != EEXIST)
        return 32;
    errno = EDOM;
    struct epoll_event output[3];
    memset(output, 0xa5, sizeof output);
    if (epoll_wait(epfd, output, 2, 1000) != 2 || output[0].events != EPOLLIN ||
        output[1].events != EPOLLIN || output[0].data.u64 == output[1].data.u64 ||
        (output[0].data.u64 != tags[0] && output[0].data.u64 != tags[1]) ||
        (output[1].data.u64 != tags[0] && output[1].data.u64 != tags[1]) ||
        output[2].events != UINT32_C(0xa5a5a5a5) ||
        output[2].data.u64 != UINT64_C(0xa5a5a5a5a5a5a5a5) || errno != EDOM)
        return 33;
    struct epoll_event replaced = {.events = EPOLLIN, .data.u64 = UINT64_C(0x1020304050607080)};
    if (epoll_ctl(epfd, EPOLL_CTL_MOD, fds[0][0], &replaced) ||
        epoll_ctl(epfd, EPOLL_CTL_DEL, fds[1][0], NULL) ||
        epoll_wait(epfd, output, 2, 0) != 1 || output[0].data.u64 != replaced.data.u64 ||
        errno != EDOM)
        return 34;
    char value;
    if (read(fds[0][0], &value, 1) != 1 || value != 'X' ||
        epoll_wait(epfd, output, 2, 0) != 0 || errno != EDOM)
        return 35;
    return close(fds[0][0]) || close(fds[0][1]) || close(fds[1][0]) ||
           close(fds[1][1]) || close(epfd) ? 36 : 0;
}

static volatile sig_atomic_t handled;

static void signal_handler(int number)
{
    if (number == SIGUSR1)
        ++handled;
}

static int mask_wait(int use_epoll)
{
    struct sigaction action = {.sa_handler = signal_handler};
    sigset_t blocked = {0}, temporary = {0}, after = {0}, pending = {0};
    if (sigemptyset(&action.sa_mask) || sigaction(SIGUSR1, &action, NULL) ||
        sigemptyset(&blocked) || sigaddset(&blocked, SIGUSR1) ||
        sigprocmask(SIG_BLOCK, &blocked, NULL) || sigemptyset(&temporary) ||
        kill(getpid(), SIGUSR1) || sigpending(&pending) ||
        sigismember(&pending, SIGUSR1) != 1 || handled)
        return 40;
    unsigned char original[sizeof temporary];
    memcpy(original, &temporary, sizeof original);
    struct timespec time = {1, 234567};
    int epfd = use_epoll ? epoll_create1(0) : -1;
    if (use_epoll && epfd < 0)
        return 41;
    struct epoll_event event;
    memset(&event, 0x66, sizeof event);
    errno = EDOM;
    int status = use_epoll ? epoll_pwait(epfd, &event, 1, 1000, &temporary)
                           : ppoll(NULL, 0, &time, &temporary);
    if (status != -1 || errno != EINTR || handled != 1 ||
        time.tv_sec != 1 || time.tv_nsec != 234567 ||
        event.data.u64 != UINT64_C(0x6666666666666666) ||
        memcmp(&temporary, original, sizeof original))
        return 42;
    errno = EDOM;
    if (sigprocmask(SIG_SETMASK, NULL, &after) || sigismember(&after, SIGUSR1) != 1 ||
        sigpending(&pending) || sigismember(&pending, SIGUSR1) || errno != EDOM)
        return 43;
    return use_epoll && close(epfd) ? 44 : 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "poll"))
        return poll_ready();
#ifndef OA_PHASE10_HOST
    if (!strcmp(argv[1], "large-count"))
        return large_count();
#endif
    if (!strcmp(argv[1], "epoll") || !strcmp(argv[1], "epoll-create1"))
        return epoll_ready(!strcmp(argv[1], "epoll-create1"));
    if (!strcmp(argv[1], "mask-poll") || !strcmp(argv[1], "mask-epoll"))
        return mask_wait(!strcmp(argv[1], "mask-epoll"));
    return 91;
}
