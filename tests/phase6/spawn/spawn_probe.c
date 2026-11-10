#include "../kernel_abi.h"
#include <signal.h>
#include <spawn.h>
#include <stdint.h>
#include <sys/wait.h>

#ifndef OA_PHASE6_HOST
_Static_assert(sizeof(posix_spawnattr_t) == 16 && _Alignof(posix_spawnattr_t) == 8,
               "project spawn attribute ABI");
_Static_assert(sizeof(posix_spawn_file_actions_t) == 16 &&
               _Alignof(posix_spawn_file_actions_t) == 8, "project spawn actions ABI");
#endif

static uint64_t bit(int number)
{
    return UINT64_C(1) << (number - 1);
}

static long mask_call(const uint64_t *set, uint64_t *old)
{
    return kernel_call(__NR_rt_sigprocmask, SIG_SETMASK, (long)set, (long)old, 8, 0, 0);
}

static long raw_wait(int child, int *status, int flags)
{
    long result;
    do {
        result = kernel_call(__NR_wait4, child, (long)status, flags, 0, 0, 0);
    } while (result == -EINTR);
    return result;
}

static int seed_input(void)
{
    int fd = (int)raw_open(AT_FDCWD, "input", O_WRONLY | O_CREAT | O_EXCL, 0600);
    return fd < 0 || raw_write(fd, "I", 1) != 1 || raw_close(fd);
}

static int child(int argc, char **argv, char **envp)
{
    if (argc != 3 || argv[3] || !same_text(argv[0], "phase6-child") ||
        !same_text(argv[2], "explicit") || !envp[0] || !envp[1] || envp[2] ||
        !same_text(envp[0], "ONLY=spawn") || !same_text(envp[1], "EMPTY="))
        return 10;
    uint64_t current = 0;
    unsigned long action[4];
    if (mask_call(NULL, &current) || current != bit(SIGUSR2) ||
        kernel_call(__NR_rt_sigaction, SIGUSR1, 0, (long)action, 8, 0, 0) || action[0])
        return 11;
    long pid = kernel_call(__NR_getpid, 0, 0, 0, 0, 0, 0);
    if (kernel_call(__NR_getpgid, 0, 0, 0, 0, 0, 0) != pid ||
        kernel_call(__NR_getuid, 0, 0, 0, 0, 0, 0) !=
        kernel_call(__NR_geteuid, 0, 0, 0, 0, 0, 0))
        return 12;
    char moved = 0, same = 0;
    if (raw_fcntl(5, K_F_GETFD, 0) != -EBADF || raw_fcntl(6, K_F_GETFD, 0) ||
        raw_fcntl(7, K_F_GETFD, 0) || raw_read(6, &moved, 1) != 1 ||
        raw_read(7, &same, 1) != 1 || moved != 'I' || same != 'I')
        return 13;
    return raw_write(STDOUT_FILENO, "spawned", 7) == 7 ? 37 : 14;
}

static int register_actions(posix_spawn_file_actions_t *actions, int ends[2], char path[6])
{
    if (posix_spawn_file_actions_init(actions) ||
        posix_spawn_file_actions_adddup2(actions, ends[1], STDOUT_FILENO) ||
        posix_spawn_file_actions_addclose(actions, ends[0]) ||
        posix_spawn_file_actions_addclose(actions, ends[1]) ||
        posix_spawn_file_actions_addopen(actions, 5, path, O_RDONLY | O_CLOEXEC, 0) ||
        posix_spawn_file_actions_adddup2(actions, 5, 6) ||
        posix_spawn_file_actions_addclose(actions, 5) ||
        posix_spawn_file_actions_addopen(actions, 7, path, O_RDONLY | O_CLOEXEC, 0) ||
        posix_spawn_file_actions_adddup2(actions, 7, 7))
        return 0;
    path[0] = 'X';
    /* A subsequent syscall keeps the post-registration write observable to the compiler. */
    return kernel_call(__NR_access, (long)path, 0, 0, 0, 0, 0) == -ENOENT;
}

static int setup_attributes(posix_spawnattr_t *attr)
{
    struct sigaction ignore = {0};
    ignore.sa_handler = SIG_IGN;
    if (sigaction(SIGUSR1, &ignore, NULL))
        return 0;
    sigset_t mask, reset;
    if (sigemptyset(&mask) || sigemptyset(&reset) ||
        sigaddset(&mask, SIGUSR2) || sigaddset(&reset, SIGUSR1))
        return 0;
    const short flags = POSIX_SPAWN_RESETIDS | POSIX_SPAWN_SETPGROUP |
                        POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK;
    return !posix_spawnattr_init(attr) && !posix_spawnattr_setflags(attr, flags) &&
           !posix_spawnattr_setpgroup(attr, 0) && !posix_spawnattr_setsigmask(attr, &mask) &&
           !posix_spawnattr_setsigdefault(attr, &reset);
}

static int spawn_errno(int result)
{
#ifdef OA_PHASE6_HOST
    if (result && errno == result)
        return 1;
# if defined(__GLIBC__)
    if (!result && errno == EBADF)
        return 1;
# endif
#else
    (void)result;
#endif
    return errno == TEST_ERRNO;
}

static int spawn_success(const char *program)
{
    int ends[2];
    if (seed_input() || kernel_call(__NR_pipe2, (long)ends, O_CLOEXEC, 0, 0, 0, 0))
        return 20;
    posix_spawn_file_actions_t actions;
    posix_spawnattr_t attr;
    char input_path[] = "input";
    if (!register_actions(&actions, ends, input_path) || !setup_attributes(&attr))
        return 21;
    uint64_t parent_mask = bit(SIGUSR1), old_mask = 0, observed = 0;
    if (mask_call(&parent_mask, &old_mask))
        return 22;
    char first[] = "phase6-child", mode[] = "spawn-child", argument[] = "explicit";
    char one[] = "ONLY=spawn", two[] = "EMPTY=";
    char *args[] = {first, mode, argument, NULL};
    char *env[] = {one, two, NULL};
    pid_t pid = -31;
    errno = TEST_ERRNO;
    if (posix_spawn(&pid, program, &actions, &attr, args, env) ||
        pid <= 0 || !spawn_errno(0))
        return 23;
    if (mask_call(NULL, &observed) || observed != parent_mask ||
        mask_call(&old_mask, NULL) || raw_close(ends[1]) ||
        posix_spawn_file_actions_destroy(&actions) || posix_spawnattr_destroy(&attr))
        return 24;
    char report[8] = {0};
    long size = raw_read(ends[0], report, sizeof report - 1);
    int status = 0;
    if (raw_wait(pid, &status, 0) != pid || status != (37 << 8) ||
        size != 7 || !same_text(report, "spawned") || raw_close(ends[0]) ||
        raw_unlink("input", 0))
        return 25;
    return 0;
}

static int spawn_failures(const char *program)
{
    char name[] = "child", *args[] = {name, NULL}, *env[] = {NULL};
    pid_t pid = -71;
    errno = TEST_ERRNO;
    if (posix_spawn(&pid, "no-such-image", NULL, NULL, args, env) != ENOENT ||
        pid != -71 || !spawn_errno(ENOENT) || raw_wait(-1, NULL, WNOHANG) != -ECHILD)
        return 31;
    posix_spawn_file_actions_t actions;
    if (posix_spawn_file_actions_init(&actions) ||
        posix_spawn_file_actions_addopen(&actions, 8, "no-such-input", O_RDONLY, 0))
        return 32;
    errno = TEST_ERRNO;
    if (posix_spawn(&pid, program, &actions, NULL, args, env) != ENOENT ||
        pid != -71 || !spawn_errno(ENOENT) || raw_wait(-1, NULL, WNOHANG) != -ECHILD ||
        posix_spawn_file_actions_destroy(&actions))
        return 33;
    if (posix_spawn_file_actions_init(&actions) ||
        posix_spawn_file_actions_adddup2(&actions, 41, 42))
        return 34;
    errno = TEST_ERRNO;
    if (raw_fcntl(41, K_F_GETFD, 0) != -EBADF ||
        posix_spawn(&pid, program, &actions, NULL, args, env) != EBADF ||
        pid != -71 || !spawn_errno(EBADF) || raw_wait(-1, NULL, WNOHANG) != -ECHILD ||
        posix_spawn_file_actions_destroy(&actions))
        return 35;
    return 0;
}

static void fill(void *storage, size_t size)
{
    unsigned char *bytes = storage;
    for (size_t i = 0; i < size; ++i)
        bytes[i] = 0xa5;
}

static int unchanged(const void *storage, size_t size)
{
    const unsigned char *bytes = storage;
    for (size_t i = 0; i < size; ++i) {
        if (bytes[i] != 0xa5)
            return 0;
    }
    return 1;
}

static uint64_t low_word(const sigset_t *mask)
{
    const unsigned char *bytes = (const unsigned char *)mask;
    uint64_t result = 0;
    for (unsigned i = 0; i < 8; ++i)
        result |= (uint64_t)bytes[i] << (8 * i);
    return result;
}

static int attribute_values(void)
{
    struct {
        uint64_t before;
        posix_spawnattr_t attr;
        uint64_t after;
    } box;
    fill(&box, sizeof box);
    errno = TEST_ERRNO;
    if (posix_spawnattr_init(&box.attr) || unchanged(&box.attr, sizeof box.attr) ||
        !unchanged(&box.before, sizeof box.before) || !unchanged(&box.after, sizeof box.after) ||
        errno != TEST_ERRNO)
        return 41;

    short flags = -1;
    if (posix_spawnattr_getflags(&box.attr, &flags) || flags != 0)
        return 42;
    const short wanted_flags = POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGMASK;
    if (posix_spawnattr_setflags(&box.attr, wanted_flags) ||
        posix_spawnattr_getflags(&box.attr, &flags) || flags != wanted_flags)
        return 43;

    pid_t group = -1;
    if (posix_spawnattr_getpgroup(&box.attr, &group) || group != 0)
        return 44;
    if (posix_spawnattr_setpgroup(&box.attr, 123) ||
        posix_spawnattr_getpgroup(&box.attr, &group) || group != 123)
        return 45;

    sigset_t value, wanted;
    fill(&value, sizeof value);
    if (posix_spawnattr_getsigmask(&box.attr, &value) || low_word(&value) != 0)
        return 46;
    if (sigemptyset(&wanted) || sigaddset(&wanted, SIGUSR2) ||
        posix_spawnattr_setsigmask(&box.attr, &wanted) || sigemptyset(&wanted) ||
        posix_spawnattr_getsigmask(&box.attr, &value) || low_word(&value) != bit(SIGUSR2))
        return 47;

    fill(&value, sizeof value);
    if (posix_spawnattr_getsigdefault(&box.attr, &value) || low_word(&value) != 0)
        return 48;
    if (sigemptyset(&wanted) || sigaddset(&wanted, SIGUSR1) ||
        posix_spawnattr_setsigdefault(&box.attr, &wanted) || sigemptyset(&wanted) ||
        posix_spawnattr_getsigdefault(&box.attr, &value) || low_word(&value) != bit(SIGUSR1))
        return 49;

#ifndef OA_PHASE6_HOST
    if (posix_spawnattr_setflags(&box.attr, 0x4000) != EINVAL ||
        posix_spawnattr_getflags(&box.attr, &flags) || flags != wanted_flags ||
        posix_spawnattr_setpgroup(&box.attr, -1) != EINVAL ||
        posix_spawnattr_getpgroup(&box.attr, &group) || group != 123)
        return 50;
#endif
    return posix_spawnattr_destroy(&box.attr) || errno != TEST_ERRNO ||
           !unchanged(&box.before, sizeof box.before) || !unchanged(&box.after, sizeof box.after) ? 51 : 0;
}

static int action_validation(void)
{
    struct {
        uint64_t before;
        posix_spawn_file_actions_t actions;
        uint64_t after;
    } box;
    fill(&box, sizeof box);
    errno = TEST_ERRNO;
    if (posix_spawn_file_actions_init(&box.actions) ||
        unchanged(&box.actions, sizeof box.actions) || errno != TEST_ERRNO)
        return 61;
    if (posix_spawn_file_actions_addclose(&box.actions, -1) != EBADF || errno != TEST_ERRNO)
        return 62;
    if (posix_spawn_file_actions_adddup2(&box.actions, -1, 7) != EBADF ||
        posix_spawn_file_actions_adddup2(&box.actions, 7, -1) != EBADF || errno != TEST_ERRNO)
        return 63;
    if (posix_spawn_file_actions_addopen(&box.actions, -1, "input", O_RDONLY, 0) != EBADF ||
        errno != TEST_ERRNO)
        return 64;
    return posix_spawn_file_actions_destroy(&box.actions) || errno != TEST_ERRNO ||
           !unchanged(&box.before, sizeof box.before) || !unchanged(&box.after, sizeof box.after) ? 65 : 0;
}

int main(int argc, char **argv, char **envp)
{
    if (argc >= 2 && same_text(argv[1], "spawn-child"))
        return child(argc, argv, envp);
    if (argc != 2)
        return 1;
    const char *mode = argv[1];
    if (same_text(mode, "success")) return spawn_success(argv[0]);
    if (same_text(mode, "failures")) return spawn_failures(argv[0]);
    if (same_text(mode, "attributes")) return attribute_values();
    if (same_text(mode, "actions")) return action_validation();
    return 2;
}
