#include "../kernel_abi.h"
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>

static uint64_t descriptor_set(void)
{
    uint64_t set = 0;
    for (int fd = 3; fd < 64; ++fd) {
        if (raw_fcntl(fd, K_F_GETFD, 0) >= 0)
            set |= UINT64_C(1) << fd;
    }
    return set;
}

static int new_fd(uint64_t before)
{
    uint64_t added = descriptor_set() & ~before;
    return added && !(added & (added - 1)) ? __builtin_ctzll(added) : -1;
}

static int child_code(int result, int code)
{
    return WIFEXITED(result) && WEXITSTATUS(result) == code && result == (code << 8);
}

static void handler(int number)
{
    (void)number;
}

static long signal_mask(uint64_t *mask)
{
    return kernel_call(__NR_rt_sigprocmask, SIG_SETMASK, 0, (long)mask, 8, 0, 0);
}

static long signal_handler(int number, unsigned long action[4])
{
    return kernel_call(__NR_rt_sigaction, number, 0, (long)action, 8, 0, 0);
}

static int same_action(const unsigned long first[4], const unsigned long second[4])
{
    for (unsigned i = 0; i < 4; ++i) {
        if (first[i] != second[i])
            return 0;
    }
    return 1;
}

static int system_case(void)
{
    errno = TEST_ERRNO;
    if (!system(NULL))
        return 11;
#if defined(OA_PHASE6_HOST) && defined(__GLIBC__)
    if (errno != TEST_ERRNO && errno != ENOSYS)
        return 11;
#else
    if (errno != TEST_ERRNO)
        return 11;
#endif
    struct sigaction action = {0};
    action.sa_handler = handler;
    if (sigemptyset(&action.sa_mask) || sigaddset(&action.sa_mask, SIGUSR1) ||
        sigaction(SIGINT, &action, NULL) || sigaction(SIGQUIT, &action, NULL))
        return 12;
    unsigned long interrupt[4], quit[4], observed[4];
    uint64_t before = 0, after = 0;
    if (signal_handler(SIGINT, interrupt) || signal_handler(SIGQUIT, quit) || signal_mask(&before))
        return 13;
    if (!child_code(system("exit 42"), 42))
        return 14;
    if (signal_handler(SIGINT, observed) || !same_action(interrupt, observed) ||
        signal_handler(SIGQUIT, observed) || !same_action(quit, observed) ||
        signal_mask(&after) || after != before)
        return 15;
    int result = system("kill -TERM $$");
    if (result < 0 || !WIFSIGNALED(result) || WTERMSIG(result) != SIGTERM)
        return 16;
    return 0;
}

static int popen_case(void)
{
    uint64_t before = descriptor_set();
    FILE *read_stream = popen("printf 'A\\000B\\377'; exit 17", "re");
    if (!read_stream)
        return 21;
    int fd = new_fd(before);
    if (fd < 0 || raw_fcntl(fd, K_F_GETFD, 0) != K_FD_CLOEXEC)
        return 22;
    unsigned char buffer[4];
    if (fread(buffer, 1, sizeof buffer, read_stream) != sizeof buffer ||
        buffer[0] != 'A' || buffer[1] != 0 || buffer[2] != 'B' || buffer[3] != 255 ||
        fgetc(read_stream) != EOF || !feof(read_stream))
        return 23;
    if (!child_code(pclose(read_stream), 17) || descriptor_set() != before)
        return 24;
    FILE *write_stream = popen("IFS= read -r line; printf '%s' \"$line\" > output; exit 23", "w");
    if (!write_stream || fputs("payload\n", write_stream) < 0 ||
        !child_code(pclose(write_stream), 23))
        return 25;
    fd = (int)raw_open(AT_FDCWD, "output", O_RDONLY, 0);
    char received[8] = {0};
    if (fd < 0 || raw_read(fd, received, sizeof received) != 7 || !same_text(received, "payload") ||
        raw_close(fd) || raw_unlink("output", 0) || descriptor_set() != before)
        return 26;
#if !defined(OA_PHASE6_HOST) || defined(__GLIBC__)
    if (popen("exit 0", "rw") || errno != EINVAL)
        return 27;
#endif
    return 0;
}

static int prior_pipe_case(void)
{
    uint64_t before = descriptor_set();
    FILE *first = popen("IFS= read -r line; exit 31", "w");
    if (!first)
        return 31;
    int fd = new_fd(before);
    if (fd < 0 || raw_fcntl(fd, K_F_GETFD, 0))
        return 32;
    char command[64];
    int length = snprintf(command, sizeof command, "test ! -e /proc/self/fd/%d", fd);
    if (length <= 0 || (size_t)length >= sizeof command)
        return 33;
    FILE *second = popen(command, "r");
    if (!second || !child_code(pclose(second), 0) ||
        !child_code(pclose(first), 31) || descriptor_set() != before)
        return 34;
    return 0;
}

static int pclose_case(void)
{
    uint64_t before = descriptor_set();
    FILE *stream = popen("exit 29", "r");
    if (!stream)
        return 40;
    if (!child_code(pclose(stream), 29) || descriptor_set() != before)
        return 41;
    return 0;
}

#ifndef OA_PHASE6_HOST
static int invalid_stream_case(void)
{
    FILE *stream = tmpfile();
    if (!stream)
        return 50;
    if (pclose(stream) != -1 || errno != EINVAL ||
        fputc('R', stream) != 'R' || fseek(stream, 0, SEEK_SET) || fgetc(stream) != 'R' || fclose(stream))
        return 51;
    return 0;
}
#endif

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    const char *mode = argv[1];
    if (same_text(mode, "system")) return system_case();
    if (same_text(mode, "popen")) return popen_case();
    if (same_text(mode, "prior-pipes")) return prior_pipe_case();
    if (same_text(mode, "pclose")) return pclose_case();
#ifndef OA_PHASE6_HOST
    if (same_text(mode, "invalid-stream")) return invalid_stream_case();
#endif
    return 2;
}
