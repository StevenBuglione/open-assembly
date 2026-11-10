#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

_Static_assert(sizeof(struct flock) == 32 && _Alignof(struct flock) == 8 &&
               offsetof(struct flock, l_type) == 0 && offsetof(struct flock, l_whence) == 2 &&
               offsetof(struct flock, l_start) == 8 && offsetof(struct flock, l_len) == 16 &&
               offsetof(struct flock, l_pid) == 24, "Linux AMD64 record lock ABI");
_Static_assert(sizeof(struct f_owner_ex) == 8 && offsetof(struct f_owner_ex, pid) == 4,
               "Linux AMD64 typed owner ABI");

static const off_t start = ((off_t)1 << 40) + 3;
static const off_t length = ((off_t)1 << 33) + 7;

static int descriptors(void)
{
    int pipefd[2];
    if (pipe(pipefd))
        return 11;
    int fd = pipefd[0];
    errno = EDOM;
    if (fcntl(fd, F_GETFD) != 0 || fcntl(fd, F_SETFD, FD_CLOEXEC) ||
        fcntl(fd, F_GETFD) != FD_CLOEXEC || errno != EDOM)
        return 12;
    int plain = fcntl(fd, F_DUPFD, 17);
    int cloexec = fcntl(fd, F_DUPFD_CLOEXEC, 29);
    if (plain < 17 || cloexec < 29 || plain == cloexec || fcntl(plain, F_GETFD) ||
        fcntl(cloexec, F_GETFD) != FD_CLOEXEC || errno != EDOM)
        return 13;
    int flags = fcntl(fd, F_GETFL);
    if (flags < 0 || (flags & O_NONBLOCK) || fcntl(plain, F_SETFL, flags | O_NONBLOCK) ||
        (fcntl(fd, F_GETFL) & O_NONBLOCK) != O_NONBLOCK ||
        (fcntl(cloexec, F_GETFL) & O_NONBLOCK) != O_NONBLOCK || errno != EDOM)
        return 14;
    char byte = '#';
    if (read(fd, &byte, 1) != -1 || errno != EAGAIN || byte != '#')
        return 15;
    errno = EDOM;
    if (fcntl(fd, F_SETFL, flags) || fcntl(plain, F_GETFL) != flags || errno != EDOM)
        return 16;
    return close(cloexec) || close(plain) || close(fd) || close(pipefd[1]) ? 17 : 0;
}

static int pipe_size(void)
{
    int fds[2];
    if (pipe(fds))
        return 21;
    errno = EDOM;
    int initial = fcntl(fds[0], F_GETPIPE_SZ);
    int changed = fcntl(fds[1], F_SETPIPE_SZ, 1);
    if (initial <= 0 || changed <= 0 || changed > initial ||
        fcntl(fds[0], F_GETPIPE_SZ) != changed || errno != EDOM)
        return 22;
    return close(fds[0]) || close(fds[1]) ? 23 : 0;
}

static struct flock lock(short type, off_t position, off_t count)
{
    return (struct flock){.l_type = type, .l_whence = SEEK_SET, .l_start = position, .l_len = count};
}

static int observed_lock(int fd, int command, off_t position, off_t count, pid_t owner)
{
    struct flock query = lock(F_RDLCK, position, count);
    errno = EDOM;
    return fcntl(fd, command, &query) == 0 && query.l_type == F_WRLCK && query.l_whence == SEEK_SET &&
           query.l_start == position && query.l_len == count && query.l_pid == owner && errno == EDOM;
}

static int no_conflict(int fd, int command)
{
    struct flock query = lock(F_RDLCK, start, length);
    errno = EDOM;
    return fcntl(fd, command, &query) == 0 && query.l_type == F_UNLCK && errno == EDOM;
}

static int child_locks(pid_t owner, int notify, int release)
{
    int fd = open("record", O_RDWR);
    if (fd < 0 || !observed_lock(fd, F_GETLK, start, length, owner))
        return 31;
    struct flock conflict = lock(F_WRLCK, start, length);
    if (fcntl(fd, F_SETLK, &conflict) != -1 || (errno != EAGAIN && errno != EACCES))
        return 32;
    struct flock disjoint = lock(F_WRLCK, start + length, 3);
    errno = EDOM;
    if (fcntl(fd, F_SETLKW, &disjoint) || errno != EDOM || write(notify, "R", 1) != 1)
        return 33;
    char marker;
    if (read(release, &marker, 1) != 1 || marker != 'G')
        return 34;
    return close(fd) ? 35 : 0;
}

static int process_locks(void)
{
    int fd = open("record", O_CREAT | O_EXCL | O_RDWR, 0600);
    int notify[2], release[2];
    if (fd < 0 || pipe(notify) || pipe(release))
        return 36;
    struct flock parent = lock(F_WRLCK, start + length, -length);
    errno = EDOM;
    if (fcntl(fd, F_SETLK, &parent) || errno != EDOM || !no_conflict(fd, F_GETLK))
        return 37;
    pid_t owner = getpid(), child = fork();
    if (child < 0)
        return 38;
    if (child == 0) {
        (void)close(notify[0]);
        (void)close(release[1]);
        _exit(child_locks(owner, notify[1], release[0]));
    }
    (void)close(notify[1]);
    (void)close(release[0]);
    char marker;
    int ready = read(notify[0], &marker, 1) == 1 && marker == 'R';
    int found = ready && observed_lock(fd, F_GETLK, start + length, 3, child);
    int released = !ready || write(release[1], "G", 1) == 1;
    (void)close(notify[0]);
    (void)close(release[1]);
    int status = 0;
    if (waitpid(child, &status, 0) != child || !WIFEXITED(status))
        return 39;
    if (WEXITSTATUS(status))
        return WEXITSTATUS(status);
    parent = lock(F_UNLCK, start, length);
    if (!found || !released || fcntl(fd, F_SETLK, &parent) || !no_conflict(fd, F_GETLK))
        return 40;
    return close(fd) ? 41 : 0;
}

static int ofd_locks(void)
{
    int fd = open("record", O_CREAT | O_EXCL | O_RDWR, 0600);
    int other = open("record", O_RDWR);
    int duplicate = fcntl(fd, F_DUPFD, 17);
    if (fd < 0 || other < 0 || duplicate < 17)
        return 42;
    struct flock lock_range = lock(F_WRLCK, start, length);
    errno = EDOM;
    if (fcntl(fd, F_OFD_SETLKW, &lock_range) || errno != EDOM || !no_conflict(duplicate, F_OFD_GETLK) ||
        !observed_lock(other, F_OFD_GETLK, start, length, -1))
        return 43;
    if (fcntl(other, F_OFD_SETLK, &lock_range) != -1 || (errno != EAGAIN && errno != EACCES))
        return 44;
    if (close(fd) || !observed_lock(other, F_OFD_GETLK, start, length, -1) ||
        close(duplicate) || !no_conflict(other, F_OFD_GETLK))
        return 45;
    if (fcntl(other, F_OFD_SETLK, &lock_range) || errno != EDOM)
        return 46;
    return close(other) ? 47 : 0;
}

#ifndef OA_PHASE6_HOST
extern long __al_syscall(long, long, long, long, long, long, long);
#endif

static pid_t current_group(void)
{
#ifdef OA_PHASE6_HOST
    return getpgrp();
#else
    enum { GETPGRP = 111 };
    return (pid_t)__al_syscall(GETPGRP, 0, 0, 0, 0, 0, 0);
#endif
}

static int establish_group(void)
{
#ifdef OA_PHASE6_HOST
    return setpgid(0, 0);
#else
    enum { SETPGID = 109 };
    return (int)__al_syscall(SETPGID, 0, 0, 0, 0, 0, 0);
#endif
}

static int owners(int sentinel)
{
    int fds[2];
    if (pipe(fds))
        return 61;
    pid_t self = getpid(), group = current_group();
    if (!sentinel && group != self) {
        if (establish_group())
            return 68;
        group = current_group();
    }
    if ((sentinel && group != 1) || (!sentinel && (group <= 1 || group != self)))
        return 69;
    struct f_owner_ex owner = {.type = F_OWNER_PID, .pid = self};
    struct f_owner_ex actual = {.type = -1, .pid = -1};
    errno = EDOM;
    if (self <= 0 || group <= 0 || fcntl(fds[0], F_SETOWN_EX, &owner) ||
        fcntl(fds[0], F_GETOWN_EX, &actual) || actual.type != F_OWNER_PID ||
        actual.pid != self || fcntl(fds[0], F_GETOWN) != self || errno != EDOM)
        return 62;
    if (fcntl(fds[0], F_SETOWN, -group) || errno != EDOM)
        return 63;
    if (fcntl(fds[0], F_GETOWN) != -group || errno != (sentinel ? EOVERFLOW : EDOM))
        return 64;
    errno = EDOM;
    if (fcntl(fds[0], F_GETOWN_EX, &actual) || actual.type != F_OWNER_PGRP ||
        actual.pid != group || errno != EDOM)
        return 65;
    if (fcntl(fds[0], F_SETOWN, 0) || fcntl(fds[0], F_GETOWN) || errno != EDOM)
        return 66;
    return close(fds[0]) || close(fds[1]) ? 67 : 0;
}

static int errors(int unknown)
{
    errno = EDOM;
    if (fcntl(-1, F_GETFD) != -1)
        return 51;
    if (errno != EBADF)
        return 52;
    if (!unknown)
        return 0;
    errno = EDOM;
    return fcntl(-1, 0x7fffffff) == -1 && errno == EINVAL ? 0 : 53;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    const char *mode = argv[1];
    if (strcmp(mode, "descriptor") == 0)
        return descriptors();
    if (strcmp(mode, "pipe-size") == 0)
        return pipe_size();
    if (strcmp(mode, "process-lock") == 0)
        return process_locks();
    if (strcmp(mode, "ofd-lock") == 0)
        return ofd_locks();
    if (strcmp(mode, "owner") == 0)
        return owners(0);
    if (strcmp(mode, "owner-sentinel") == 0)
        return owners(1);
    if (strcmp(mode, "bad-fd") == 0)
        return errors(0);
    if (strcmp(mode, "unknown") == 0)
        return errors(1);
    return 91;
}
