#include "kernel_abi.h"
#include <sys/stat.h>

#define CHECK_OFFSET(type, member, offset) \
    _Static_assert(offsetof(type, member) == (offset), #type "." #member)

_Static_assert(sizeof(struct stat) == 144 && _Alignof(struct stat) == 8, "stat ABI");
_Static_assert(sizeof(struct timespec) == 16 && _Alignof(struct timespec) == 8, "timespec ABI");
CHECK_OFFSET(struct timespec, tv_sec, 0);
CHECK_OFFSET(struct timespec, tv_nsec, 8);

CHECK_OFFSET(struct stat, st_dev, 0);
CHECK_OFFSET(struct stat, st_ino, 8);
CHECK_OFFSET(struct stat, st_nlink, 16);
CHECK_OFFSET(struct stat, st_mode, 24);
CHECK_OFFSET(struct stat, st_uid, 28);
CHECK_OFFSET(struct stat, st_gid, 32);
CHECK_OFFSET(struct stat, st_rdev, 40);
CHECK_OFFSET(struct stat, st_size, 48);
CHECK_OFFSET(struct stat, st_blksize, 56);
CHECK_OFFSET(struct stat, st_blocks, 64);
CHECK_OFFSET(struct stat, st_atim, 72);
CHECK_OFFSET(struct stat, st_mtim, 88);
CHECK_OFFSET(struct stat, st_ctim, 104);

CHECK_OFFSET(struct kernel_stat, device, 0);
CHECK_OFFSET(struct kernel_stat, inode, 8);
CHECK_OFFSET(struct kernel_stat, links, 16);
CHECK_OFFSET(struct kernel_stat, mode, 24);
CHECK_OFFSET(struct kernel_stat, uid, 28);
CHECK_OFFSET(struct kernel_stat, gid, 32);
CHECK_OFFSET(struct kernel_stat, reserved, 36);
CHECK_OFFSET(struct kernel_stat, rdevice, 40);
CHECK_OFFSET(struct kernel_stat, size, 48);
CHECK_OFFSET(struct kernel_stat, block_size, 56);
CHECK_OFFSET(struct kernel_stat, blocks, 64);
CHECK_OFFSET(struct kernel_stat, atime_seconds, 72);
CHECK_OFFSET(struct kernel_stat, atime_ns, 80);
CHECK_OFFSET(struct kernel_stat, mtime_seconds, 88);
CHECK_OFFSET(struct kernel_stat, mtime_ns, 96);
CHECK_OFFSET(struct kernel_stat, ctime_seconds, 104);
CHECK_OFFSET(struct kernel_stat, ctime_ns, 112);
CHECK_OFFSET(struct kernel_stat, unused, 120);

static void fill_bytes(void *storage, size_t size, unsigned char value)
{
    unsigned char *p = storage;
    for (size_t i = 0; i < size; ++i)
        p[i] = value;
}

static int all_bytes(const void *storage, size_t size, unsigned char value)
{
    const unsigned char *p = storage;
    for (size_t i = 0; i < size; ++i) {
        if (p[i] != value)
            return 0;
    }
    return 1;
}

struct boxed_stat {
    unsigned long left;
    struct stat value;
    unsigned long right;
};

static int stat_matches(const struct boxed_stat *box, const struct kernel_stat *want)
{
    if (!all_bytes(&box->left, sizeof box->left, 0xA5) ||
        !all_bytes(&box->right, sizeof box->right, 0xA5))
        return 0;
#ifndef OA_PHASE6_HOST
    const unsigned char *bytes = (const unsigned char *)&box->value;
    if (!all_bytes(bytes + 36, 4, 0) || !all_bytes(bytes + 120, 24, 0))
        return 0;
#endif
    const struct stat *got = &box->value;
    return got->st_dev == want->device && got->st_ino == want->inode &&
           got->st_nlink == want->links && got->st_mode == want->mode &&
           got->st_uid == want->uid && got->st_gid == want->gid &&
           got->st_rdev == want->rdevice && got->st_size == want->size &&
           got->st_blksize == want->block_size && got->st_blocks == want->blocks &&
           got->st_atim.tv_sec == want->atime_seconds && got->st_atim.tv_nsec == want->atime_ns &&
           got->st_mtim.tv_sec == want->mtime_seconds && got->st_mtim.tv_nsec == want->mtime_ns &&
           got->st_ctim.tv_sec == want->ctime_seconds && got->st_ctim.tv_nsec == want->ctime_ns;
}

static int stat_case(const char *which)
{
    if (raw_mkdir("dir", 0700))
        return 10;
    int dir = (int)raw_open(AT_FDCWD, "dir", O_RDONLY | O_DIRECTORY, 0);
    int fd = (int)raw_open(dir, "target", O_RDWR | O_CREAT | O_EXCL, 0641);
    const long times[4] = {-123, 784123456, (1L << 32) + 5, 210987654};
    if (dir < 0 || fd < 0 || raw_write(fd, "stat", 4) != 4 ||
        kernel_call(__NR_utimensat, dir, (long)"target", (long)times, 0, 0, 0) ||
        kernel_call(__NR_symlinkat, (long)"target", dir, (long)"link", 0, 0, 0))
        return 11;
    struct boxed_stat got;
    struct kernel_stat want;
    int result, error;
    fill_bytes(&got, sizeof got, 0xA5);
    if (same_text(which, "stat")) {
        if (raw_stat(AT_FDCWD, "dir/link", 0, &want) ||
            !S_ISREG(want.mode) || want.size != 4)
            return 12;
        errno = TEST_ERRNO;
        result = stat("dir/link", &got.value);
    } else if (same_text(which, "lstat")) {
        if (raw_stat(AT_FDCWD, "dir/link", K_AT_SYMLINK_NOFOLLOW, &want) ||
            !S_ISLNK(want.mode) || want.size != 6)
            return 13;
        errno = TEST_ERRNO;
        result = lstat("dir/link", &got.value);
    } else if (same_text(which, "fstat")) {
        if (raw_unlink("dir/target", 0) || raw_fstat(fd, &want) ||
            want.links != 0 || want.size != 4)
            return 14;
        errno = TEST_ERRNO;
        result = fstat(fd, &got.value);
    } else {
        if (raw_stat(dir, "link", K_AT_SYMLINK_NOFOLLOW, &want) || !S_ISLNK(want.mode))
            return 15;
        errno = TEST_ERRNO;
        result = fstatat(dir, "link", &got.value, AT_SYMLINK_NOFOLLOW);
    }
    if (result || errno != TEST_ERRNO || !stat_matches(&got, &want))
        return 16;

    if (same_text(which, "fstatat")) {
        fill_bytes(&got, sizeof got, 0xA5);
        if (raw_fstat(fd, &want) ||
            fstatat(fd, "", &got.value, AT_EMPTY_PATH) || !stat_matches(&got, &want))
            return 17;
    }
    fill_bytes(&got, sizeof got, 0xA5);
    error = ENOENT;
    if (same_text(which, "stat"))
        result = stat("missing", &got.value);
    else if (same_text(which, "lstat"))
        result = lstat("missing", &got.value);
    else if (same_text(which, "fstat")) {
        result = fstat(-1, &got.value);
        error = EBADF;
    } else {
        result = fstatat(-1, "relative", &got.value, 0);
        error = EBADF;
    }
    if (result != -1 || errno != error || !all_bytes(&got, sizeof got, 0xA5))
        return 18;
    if (!same_text(which, "fstat") && raw_unlink("dir/target", 0))
        return 19;
    return raw_close(fd) || raw_close(dir) || raw_unlink("dir/link", 0) ||
           raw_unlink("dir", K_AT_REMOVEDIR) ? 20 : 0;
}

int main(int argc, char **argv)
{
    return argc == 2 ? stat_case(argv[1]) : 1;
}
