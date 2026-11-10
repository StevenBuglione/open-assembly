#include "../kernel_abi.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

static int seeded(const char *path, char byte)
{
    int fd = (int)raw_open(AT_FDCWD, path, O_RDWR | O_CREAT | O_EXCL, 0600);
    if (fd < 0 || raw_write(fd, &byte, 1) != 1 || raw_seek(fd, 0, SEEK_SET))
        return -1;
    return fd;
}

static int remove_case(void)
{
    int fd = seeded("file", 'F');
    if (fd < 0)
        return 10;
    errno = TEST_ERRNO;
    struct kernel_stat status;
    char byte = 0;
    if (remove("file") || errno != TEST_ERRNO ||
        raw_stat(AT_FDCWD, "file", 0, &status) != -ENOENT ||
        raw_fstat(fd, &status) || status.links || raw_read(fd, &byte, 1) != 1 ||
        byte != 'F' || raw_close(fd))
        return 11;

    fd = seeded("target", 'T');
    if (fd < 0 || raw_close(fd) ||
        kernel_call(__NR_symlinkat, (long)"target", AT_FDCWD, (long)"link", 0, 0, 0))
        return 12;
    if (remove("link") || raw_stat(AT_FDCWD, "link", K_AT_SYMLINK_NOFOLLOW, &status) != -ENOENT ||
        raw_stat(AT_FDCWD, "target", 0, &status) || !S_ISREG(status.mode) || raw_unlink("target", 0))
        return 13;
    if (raw_mkdir("directory", 0700))
        return 14;
    fd = seeded("directory/file", 'D');
    if (fd < 0 || raw_close(fd) || remove("directory") != -1 || errno != ENOTEMPTY)
        return 15;
    if (raw_unlink("directory/file", 0) || remove("directory") ||
        raw_stat(AT_FDCWD, "directory", 0, &status) != -ENOENT)
        return 16;
    return remove("missing") != -1 || errno != ENOENT ? 17 : 0;
}

static int rename_case(void)
{
    int old = seeded("before", 'A'), replaced = seeded("after", 'B');
    if (old < 0 || replaced < 0)
        return 20;
    errno = TEST_ERRNO;
    if (rename("before", "after") || errno != TEST_ERRNO)
        return 21;
    struct kernel_stat named, original, displaced;
    if (raw_stat(AT_FDCWD, "before", 0, &named) != -ENOENT ||
        raw_stat(AT_FDCWD, "after", 0, &named) || raw_fstat(old, &original) ||
        raw_fstat(replaced, &displaced) || displaced.links ||
        named.inode != original.inode || named.device != original.device)
        return 22;
    char byte = 0;
    if (raw_read(old, &byte, 1) != 1 || byte != 'A' ||
        raw_read(replaced, &byte, 1) != 1 || byte != 'B' || raw_close(old) || raw_close(replaced))
        return 23;
    if (kernel_call(__NR_symlinkat, (long)"after", AT_FDCWD, (long)"link", 0, 0, 0))
        return 24;
    if (rename("link", "moved") || rename("moved", "moved") ||
        raw_stat(AT_FDCWD, "link", K_AT_SYMLINK_NOFOLLOW, &named) != -ENOENT ||
        raw_stat(AT_FDCWD, "moved", K_AT_SYMLINK_NOFOLLOW, &named) || !S_ISLNK(named.mode))
        return 25;
    if (rename("missing", "after") != -1 || errno != ENOENT ||
        raw_stat(AT_FDCWD, "after", 0, &named) || named.inode != original.inode)
        return 26;
    return raw_unlink("moved", 0) || raw_unlink("after", 0) ? 27 : 0;
}

static int made_name(const char *name)
{
    const char prefix[] = "item-";
    for (size_t i = 0; i < sizeof prefix - 1; ++i) {
        if (name[i] != prefix[i])
            return 0;
    }
    for (unsigned i = 5; i < 11; ++i) {
        char c = name[i];
        if (!((c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')))
            return 0;
    }
    return name[11] == '\0';
}

static int mkstemp_case(void)
{
    char first[] = "item-XXXXXX", second[] = "item-XXXXXX";
    if (kernel_call(__NR_umask, 0, 0, 0, 0, 0, 0) < 0)
        return 40;
    errno = TEST_ERRNO;
    int one = mkstemp(first);
    if (one < 3 || errno != TEST_ERRNO || !made_name(first))
        return 41;
    int two = mkstemp(second);
    if (two < 3 || errno != TEST_ERRNO || !made_name(second) || same_text(first, second))
        return 42;
    struct kernel_stat first_status, second_status;
    char byte = 0;
    if (raw_fstat(one, &first_status) || raw_fstat(two, &second_status) ||
        !S_ISREG(first_status.mode) || !S_ISREG(second_status.mode) ||
        (first_status.mode & 0777) != 0600 || (second_status.mode & 0777) != 0600 ||
        first_status.inode == second_status.inode ||
        (raw_fcntl(one, K_F_GETFL, 0) & O_ACCMODE) != O_RDWR ||
        raw_write(one, "T", 1) != 1 || raw_seek(one, 0, SEEK_SET) ||
        raw_read(one, &byte, 1) != 1 || byte != 'T')
        return 43;
    char short_template[] = "item-XXXXX", bad_parent[] = "missing/item-XXXXXX";
    if (mkstemp(short_template) != -1 || errno != EINVAL || !same_text(short_template, "item-XXXXX"))
        return 44;
    if (mkstemp(bad_parent) != -1 || errno != ENOENT)
        return 45;
#ifndef OA_PHASE6_HOST
    if (!same_text(bad_parent, "missing/item-XXXXXX"))
        return 46;
#endif
    return raw_close(one) || raw_close(two) || raw_unlink(first, 0) || raw_unlink(second, 0) ? 47 : 0;
}

static uint64_t open_descriptors(void)
{
    uint64_t occupied = 0;
    for (unsigned fd = 3; fd < 64; ++fd) {
        if (raw_fcntl((int)fd, K_F_GETFD, 0) >= 0)
            occupied |= UINT64_C(1) << fd;
    }
    return occupied;
}

static int tmpfile_case(void)
{
    uint64_t before = open_descriptors();
    errno = TEST_ERRNO;
    FILE *file = tmpfile();
    if (!file || errno != TEST_ERRNO)
        return 61;
    uint64_t added = open_descriptors() & ~before;
    if (!added || (added & (added - 1)))
        return 62;
    int fd = __builtin_ctzll(added);
    struct kernel_stat status;
    if (raw_fstat(fd, &status) || !S_ISREG(status.mode) || status.links ||
        (raw_fcntl(fd, K_F_GETFL, 0) & O_ACCMODE) != O_RDWR)
        return 63;
#ifndef OA_PHASE6_HOST
    if (raw_fcntl(fd, K_F_GETFD, 0) != K_FD_CLOEXEC)
        return 64;
#endif
    static const unsigned char want[] = {'A', 0, 255, 'Z'};
    if (fwrite(want, 1, sizeof want, file) != sizeof want)
        return 65;
#ifndef OA_PHASE6_HOST
    if (raw_fstat(fd, &status) || status.size != 0)
        return 66;
#endif
    if (fseek(file, 0, SEEK_SET))
        return 67;
    unsigned char got[sizeof want];
    if (fread(got, 1, sizeof got, file) != sizeof got)
        return 68;
    for (size_t i = 0; i < sizeof got; ++i) {
        if (got[i] != want[i])
            return 69;
    }
    return fclose(file) || open_descriptors() != before ? 70 : 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    const char *mode = argv[1];
    if (same_text(mode, "remove")) return remove_case();
    if (same_text(mode, "rename")) return rename_case();
    if (same_text(mode, "mkstemp")) return mkstemp_case();
    if (same_text(mode, "tmpfile")) return tmpfile_case();
    return 2;
}
