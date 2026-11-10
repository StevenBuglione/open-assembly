#ifndef OA_STAT_IDENTITY_FIXTURE_H
#define OA_STAT_IDENTITY_FIXTURE_H

#include "../kernel_abi.h"

#include <stdint.h>
#include <sys/stat.h>

enum operation { STAT, FSTAT, LSTAT, FSTATAT, BAD_OPERATION };

struct stat_box {
    uint64_t left;
    struct stat value;
    uint64_t right;
};

static inline enum operation operation_from(const char *name)
{
    if (same_text(name, "stat"))
        return STAT;
    if (same_text(name, "fstat"))
        return FSTAT;
    if (same_text(name, "lstat"))
        return LSTAT;
    if (same_text(name, "fstatat"))
        return FSTATAT;
    return BAD_OPERATION;
}

static inline void set_bytes(void *object, size_t count, unsigned char byte)
{
    unsigned char *bytes = object;
    for (size_t i = 0; i < count; ++i)
        bytes[i] = byte;
}

static inline int all_bytes(const void *object, size_t count, unsigned char byte)
{
    const unsigned char *bytes = object;
    for (size_t i = 0; i < count; ++i)
        if (bytes[i] != byte)
            return 0;
    return 1;
}

static inline int edges(const struct stat_box *box)
{
    return all_bytes(&box->left, sizeof box->left, 0xa5) &&
           all_bytes(&box->right, sizeof box->right, 0xa5);
}

static inline int padding(const struct stat_box *box)
{
#ifndef OA_PHASE6_HOST
    const unsigned char *bytes = (const unsigned char *)&box->value;
    return all_bytes(bytes + 36, 4, 0) && all_bytes(bytes + 120, 24, 0);
#else
    (void)box;
    return 1;
#endif
}

static inline int exact_fields(const struct stat *actual, const struct kernel_stat *raw)
{
    return actual->st_dev == raw->device && actual->st_ino == raw->inode &&
           actual->st_nlink == raw->links && actual->st_mode == raw->mode &&
           actual->st_uid == raw->uid && actual->st_gid == raw->gid &&
           actual->st_rdev == raw->rdevice && actual->st_size == raw->size &&
           actual->st_blksize == raw->block_size && actual->st_blocks == raw->blocks &&
           actual->st_atim.tv_sec == raw->atime_seconds && actual->st_atim.tv_nsec == raw->atime_ns &&
           actual->st_mtim.tv_sec == raw->mtime_seconds && actual->st_mtim.tv_nsec == raw->mtime_ns &&
           actual->st_ctim.tv_sec == raw->ctime_seconds && actual->st_ctim.tv_nsec == raw->ctime_ns;
}

static inline int symlink_at(const char *target, int fd, const char *path)
{
    return kernel_call(__NR_symlinkat, (long)target, fd, (long)path, 0, 0, 0) == 0;
}

#endif
