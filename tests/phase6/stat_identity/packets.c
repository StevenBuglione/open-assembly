#include "fixture.h"

struct stimulus { uint64_t mode, value; };
struct observed {
    int64_t result, error, size;
    uint64_t scenario, mode, links, timestamp, precision;
};
_Static_assert(sizeof(struct stimulus) == 16 && sizeof(struct observed) == 64,
               "Linux LP64 wire widths");

struct fixture {
    int parent, directory;
    char absolute[4096];
};

struct file {
    int fd, links, extra, pipe[2];
    unsigned mode;
    long size, times[4];
};

struct target {
    int fd, flags, error;
    const char *path;
    unsigned kind;
};

enum { REGULAR = 1, SYMLINK, DIRECTORY, FIFO };
enum { K_F_DUPFD_CLOEXEC = 1030 };

static int read_row(struct stimulus *input)
{
    size_t done = 0;
    while (done < sizeof *input) {
        long n = raw_read(STDIN_FILENO, (char *)input + done, sizeof *input - done);
        if (n == -EINTR)
            continue;
        if (n < 0 || (!n && done))
            return -1;
        if (!n)
            return 0;
        done += (size_t)n;
    }
    return 1;
}

static int write_row(const struct observed *output)
{
    size_t done = 0;
    while (done < sizeof *output) {
        long n = raw_write(STDOUT_FILENO, (const char *)output + done, sizeof *output - done);
        if (n == -EINTR)
            continue;
        if (n <= 0)
            return 0;
        done += (size_t)n;
    }
    return 1;
}

static const char root_name[] = "stat-packet-root";

static int setup(struct fixture *fixture)
{
    fixture->parent = (int)raw_open(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0);
    if (fixture->parent < 0 || raw_mkdir(root_name, 0700) ||
        kernel_call(__NR_chdir, (long)root_name, 0, 0, 0, 0, 0) || raw_mkdir("nested", 0700))
        return 0;
    fixture->directory = (int)raw_open(AT_FDCWD, "nested", O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0);
    int decoy = (int)raw_open(AT_FDCWD, "file", O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC, 0600);
    static const char suffix[] = "/nested/file";
    long length = kernel_call(__NR_getcwd, (long)fixture->absolute, sizeof fixture->absolute,
                              0, 0, 0, 0);
    if (fixture->directory < 0 || decoy < 0 || raw_write(decoy, "other", 5) != 5 ||
        raw_close(decoy) || length < 2 || (size_t)length + sizeof suffix - 1 > sizeof fixture->absolute)
        return 0;
    for (size_t i = 0; i < sizeof suffix; ++i)
        fixture->absolute[length - 1 + i] = suffix[i];
    return symlink_at("file", fixture->directory, "link") &&
           symlink_at("absent", fixture->directory, "dangling") &&
           symlink_at("loop", fixture->directory, "loop");
}

static int cleanup(const struct fixture *fixture)
{
    int result = raw_unlink("nested/link", 0) == 0;
    result &= raw_unlink("nested/dangling", 0) == 0;
    result &= raw_unlink("nested/loop", 0) == 0;
    result &= raw_unlink("file", 0) == 0;
    result &= raw_close(fixture->directory) == 0;
    result &= raw_unlink("nested", K_AT_REMOVEDIR) == 0;
    if (kernel_call(__NR_fchdir, fixture->parent, 0, 0, 0, 0, 0))
        return 0;
    result &= raw_close(fixture->parent) == 0;
    return raw_unlink(root_name, K_AT_REMOVEDIR) == 0 && result;
}

static int prepare(struct file *file, const struct fixture *fixture, uint64_t seed)
{
    file->mode = 0600U | (unsigned)((seed >> 8) & 077);
    file->size = (long)(seed & 1023);
    if (seed >> 63)
        file->size += 1L << 32;
    file->times[0] = -123 - (long)((seed >> 20) & 255);
    file->times[1] = 784123456 + (long)((seed >> 28) & 65535);
    file->times[2] = (1L << 32) + 5 + (long)((seed >> 12) & 255);
    file->times[3] = 210987654 + (long)((seed >> 36) & 65535);
    file->fd = (int)raw_open(fixture->directory, "file", O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC,
                             file->mode);
    if (file->fd < 0)
        return 0;
    file->links = 1;
    if (kernel_call(__NR_ftruncate, file->fd, file->size, 0, 0, 0, 0) ||
        kernel_call(__NR_utimensat, fixture->directory, (long)"file", (long)file->times, 0, 0, 0))
        return 0;
    if ((seed >> 19) & 1) {
        if (kernel_call(__NR_linkat, fixture->directory, (long)"file", fixture->directory,
                        (long)"alias", 0, 0))
            return 0;
        file->links = 2;
    }
    return 1;
}

static int unlink_names(struct file *file)
{
    if (file->links == 2) {
        if (raw_unlink("nested/alias", 0))
            return 0;
        --file->links;
    }
    if (file->links == 1) {
        if (raw_unlink("nested/file", 0))
            return 0;
        --file->links;
    }
    return 1;
}

static int close_row(struct file *file)
{
    int result = unlink_names(file);
    if (file->fd >= 0)
        result &= raw_close(file->fd) == 0;
    if (file->extra >= 0)
        result &= raw_close(file->extra) == 0;
    for (unsigned i = 0; i < 2; ++i)
        if (file->pipe[i] >= 0)
            result &= raw_close(file->pipe[i]) == 0;
    return result;
}

static int descriptor_target(unsigned mode, struct target *target,
                             struct file *file, const struct fixture *fixture)
{
    *target = (struct target){file->fd, 0, 0, "", REGULAR};
    switch (mode) {
    case 0:
        return 1;
    case 1:
        return unlink_names(file);
    case 2:
        target->fd = fixture->directory;
        target->kind = DIRECTORY;
        return 1;
    case 3:
        target->fd = -1;
        break;
    case 4: {
        long duplicate = raw_fcntl(file->fd, K_F_DUPFD_CLOEXEC, 20);
        if (duplicate < 0 || raw_close((int)duplicate))
            return 0;
        target->fd = (int)duplicate;
        break;
    }
    case 5:
        file->extra = (int)raw_open(fixture->directory, "link", O_PATH | O_NOFOLLOW | O_CLOEXEC, 0);
        target->fd = file->extra;
        target->kind = SYMLINK;
        return file->extra >= 0;
    case 6:
        if (kernel_call(__NR_pipe2, (long)file->pipe, O_CLOEXEC, 0, 0, 0, 0))
            return 0;
        target->fd = file->pipe[0];
        target->kind = FIFO;
        return 1;
    }
    target->error = EBADF;
    target->kind = 0;
    return 1;
}

static struct target pathname_target(unsigned mode, int nofollow)
{
    int flags = nofollow ? K_AT_SYMLINK_NOFOLLOW : 0;
    switch (mode) {
    case 0: return (struct target){AT_FDCWD, flags, 0, "nested/file", REGULAR};
    case 1: return (struct target){AT_FDCWD, flags, 0, "nested/link", nofollow ? SYMLINK : REGULAR};
    case 2: return (struct target){AT_FDCWD, flags, nofollow ? 0 : ENOENT, "nested/dangling",
                                   nofollow ? SYMLINK : 0};
    case 3: return (struct target){AT_FDCWD, flags, 0, "nested", DIRECTORY};
    case 4: return (struct target){AT_FDCWD, flags, ENOENT, "nested/missing", 0};
    case 5: return (struct target){AT_FDCWD, flags, ENOTDIR, "nested/file/child", 0};
    case 6: return (struct target){AT_FDCWD, flags, nofollow ? 0 : ELOOP, "nested/loop",
                                   nofollow ? SYMLINK : 0};
    case 7: return (struct target){AT_FDCWD, flags, ENOTDIR, "nested/link/", 0};
    default: return (struct target){AT_FDCWD, flags, ELOOP, "nested/loop/child", 0};
    }
}

static int relative_target(unsigned mode, struct target *target,
                           struct file *file, const struct fixture *fixture)
{
    *target = (struct target){fixture->directory, 0, 0, "file", REGULAR};
    switch (mode) {
    case 0:
        break;
    case 1:
        target->path = "link";
        break;
    case 2:
        target->path = "link";
        target->flags = AT_SYMLINK_NOFOLLOW;
        target->kind = SYMLINK;
        break;
    case 3:
        target->fd = AT_FDCWD;
        target->path = "nested/file";
        break;
    case 4:
        target->fd = -1;
        target->path = fixture->absolute;
        break;
    case 5:
    case 6:
        if (mode == 6 && !unlink_names(file))
            return 0;
        target->fd = file->fd;
        target->path = "";
        target->flags = AT_EMPTY_PATH;
        break;
    case 7:
        file->extra = (int)raw_open(fixture->directory, "link", O_PATH | O_NOFOLLOW | O_CLOEXEC, 0);
        if (file->extra < 0)
            return 0;
        *target = (struct target){file->extra, AT_EMPTY_PATH | AT_SYMLINK_NOFOLLOW, 0, "", SYMLINK};
        break;
    case 8:
        *target = (struct target){-1, 0, EBADF, "file", 0};
        break;
    case 9:
        *target = (struct target){fixture->directory, 0x40000000, EINVAL, "file", 0};
        break;
    case 10:
        *target = (struct target){fixture->directory, 0, ENOENT, "", 0};
        break;
    case 11:
        *target = (struct target){file->fd, 0, ENOTDIR, "child", 0};
        break;
    case 12:
        *target = (struct target){fixture->directory, AT_SYMLINK_NOFOLLOW, 0, "dangling", SYMLINK};
        break;
    }
    return 1;
}

static int public_call(enum operation operation, const struct target *target, struct stat *output)
{
    if (operation == STAT)
        return stat(target->path, output);
    if (operation == LSTAT)
        return lstat(target->path, output);
    if (operation == FSTAT)
        return fstat(target->fd, output);
    return fstatat(target->fd, target->path, output, target->flags);
}

static int known_object(const struct target *target, const struct file *file,
                        const struct fixture *fixture, const struct kernel_stat *raw)
{
    static const unsigned kinds[] = {0, 0100000, 0120000, 0040000, 0010000};
    if ((raw->mode & 0170000) != kinds[target->kind])
        return 0;
    if (target->kind == REGULAR || target->kind == DIRECTORY) {
        struct kernel_stat descriptor;
        int fd = target->kind == REGULAR ? file->fd : fixture->directory;
        if (raw_fstat(fd, &descriptor) || descriptor.device != raw->device ||
            descriptor.inode != raw->inode)
            return 0;
    }
    if (target->kind == REGULAR)
        return (raw->mode & 0777) == file->mode && raw->size == file->size &&
               raw->links == (uint64_t)file->links;
    if (target->kind == SYMLINK) {
        int dangling = same_text(target->path, "dangling") || same_text(target->path, "nested/dangling");
        return raw->size == (dangling ? 6 : 4) && raw->links == 1;
    }
    return 1;
}

static void deterministic_fields(struct observed *output, unsigned kind,
                                 const struct stat *actual, const struct file *file)
{
    output->mode = actual->st_mode;
    if (kind != REGULAR && kind != SYMLINK)
        return;
    output->size = actual->st_size;
    output->links = actual->st_nlink;
    if (kind == REGULAR) {
        const long times[] = {actual->st_atim.tv_sec, actual->st_atim.tv_nsec,
                              actual->st_mtim.tv_sec, actual->st_mtim.tv_nsec};
        for (unsigned i = 0; i < sizeof times / sizeof *times; ++i) {
            output->timestamp = output->timestamp * UINT64_C(4294967311) + (uint64_t)times[i];
            if (times[i] == file->times[i])
                output->precision |= UINT64_C(1) << i;
        }
    }
}

static int observe(enum operation operation, struct stimulus input, const struct fixture *fixture,
                   struct observed *output)
{
    struct file file = {.fd = -1, .extra = -1, .pipe = {-1, -1}};
    int result = 91;
    if (!prepare(&file, fixture, input.value))
        goto done;
    struct target target;
    if (operation == FSTAT) {
        output->scenario = input.mode % 7;
        if (!descriptor_target((unsigned)output->scenario, &target, &file, fixture))
            goto done;
    } else if (operation == FSTATAT) {
        output->scenario = input.mode % 13;
        if (!relative_target((unsigned)output->scenario, &target, &file, fixture))
            goto done;
    } else {
        output->scenario = input.mode % 9;
        target = pathname_target((unsigned)output->scenario, operation == LSTAT);
    }
    struct kernel_stat expected;
    long raw = operation == FSTAT ? raw_fstat(target.fd, &expected) :
               raw_stat(target.fd, target.path, target.flags, &expected);
    result = 92;
    if (raw != -target.error || (!raw && !known_object(&target, &file, fixture, &expected)))
        goto done;

    struct stat_box box;
    set_bytes(&box, sizeof box, 0xa5);
    int sentinel = 701 + (int)((input.value >> 44) & 2047);
    errno = sentinel;
    int returned = public_call(operation, &target, &box.value);
    int error = errno;
    result = 21;
    if (returned != (target.error ? -1 : 0) || error != (target.error ? target.error : sentinel))
        goto done;
    result = 23;
    if (target.error ? !all_bytes(&box, sizeof box, 0xa5) : !edges(&box) || !padding(&box))
        goto done;
    result = 22;
    if (!target.error && !exact_fields(&box.value, &expected))
        goto done;
    output->result = returned;
    output->error = error;
    if (!target.error)
        deterministic_fields(output, target.kind, &box.value, &file);
    result = 0;
done:
    return close_row(&file) ? result : 93;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    enum operation operation = operation_from(argv[1]);
    if (operation == BAD_OPERATION)
        return 90;
    (void)kernel_call(__NR_umask, 0, 0, 0, 0, 0, 0);
    struct fixture fixture;
    if (!setup(&fixture))
        return 91;
    int result = 0;
    struct stimulus input;
    while (!result) {
        int got = read_row(&input);
        if (got <= 0) {
            if (got < 0)
                result = 94;
            break;
        }
        struct observed output = {0};
        result = observe(operation, input, &fixture, &output);
        if (!result && !write_row(&output))
            result = 94;
    }
    return cleanup(&fixture) ? result : 95;
}
