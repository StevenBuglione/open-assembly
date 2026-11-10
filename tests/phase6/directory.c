#include "kernel_abi.h"
#include <dirent.h>
#include <stdint.h>

_Static_assert(offsetof(struct dirent, d_ino) == 0, "dirent inode");
_Static_assert(offsetof(struct dirent, d_off) == 8, "dirent cookie");
_Static_assert(offsetof(struct dirent, d_reclen) == 16, "dirent reclen");
_Static_assert(offsetof(struct dirent, d_type) == 18, "dirent type");
_Static_assert(offsetof(struct dirent, d_name) == 19, "dirent name");
_Static_assert(sizeof(struct dirent) == 280 && _Alignof(struct dirent) == 8, "dirent ABI");

struct entry_reference {
    const char *name;
    uint64_t inode;
    unsigned short length;
    unsigned char type;
};

static uint64_t load_le(const unsigned char *bytes, unsigned count)
{
    uint64_t result = 0;
    for (unsigned i = 0; i < count; ++i)
        result |= (uint64_t)bytes[i] << (i * 8);
    return result;
}

static int bounded_name(const char *name, size_t available)
{
    for (size_t i = 0; i < available; ++i) {
        if (name[i] == '\0')
            return 1;
    }
    return 0;
}

static int name_index(const struct entry_reference *expected, int count, const char *name)
{
    for (int i = 0; i < count; ++i) {
        if (same_text(expected[i].name, name))
            return i;
    }
    return -1;
}

static int raw_directory_reference(struct entry_reference *expected, int count)
{
    /* Linux fs/readdir.c struct linux_dirent64 records, little endian. */
    int fd = (int)raw_open(AT_FDCWD, "entries", O_RDONLY | O_DIRECTORY, 0);
    if (fd < 0)
        return 0;
    unsigned char bytes[4096];
    unsigned seen = 0;
    for (;;) {
        long size = kernel_call(__NR_getdents64, fd, (long)bytes, sizeof bytes, 0, 0, 0);
        if (size < 0 || size > (long)sizeof bytes)
            return 0;
        if (size == 0)
            break;
        for (size_t offset = 0; offset < (size_t)size;) {
            size_t remaining = (size_t)size - offset;
            const unsigned char *entry = bytes + offset;
            if (remaining < 20)
                return 0;
            unsigned short length = (unsigned short)load_le(entry + 16, 2);
            const char *name = (const char *)(entry + 19);
            if (length < 20 || length > remaining || !bounded_name(name, length - 19))
                return 0;
            int index = name_index(expected, count, name);
            if (index < 0 || (seen & (1U << index)))
                return 0;
            seen |= 1U << index;
            expected[index].inode = load_le(entry, 8);
            expected[index].length = length;
            expected[index].type = entry[18];
            offset += length;
        }
    }
    return !raw_close(fd) && seen == (1U << count) - 1;
}

static int readdir_case(void)
{
    static char long_name[256];
    for (size_t i = 0; i < sizeof long_name - 1; ++i)
        long_name[i] = (char)('a' + i % 26);

    if (raw_mkdir("entries", 0700) || raw_mkdir("entries/sub", 0700))
        return 30;
    int fd = (int)raw_open(AT_FDCWD, "entries", O_RDONLY | O_DIRECTORY, 0);
    if (fd < 0)
        return 31;
    int plain = (int)raw_open(fd, "plain", O_RDWR | O_CREAT | O_EXCL, 0600);
    int longest = (int)raw_open(fd, long_name, O_RDWR | O_CREAT | O_EXCL, 0600);
    if (plain < 0 || longest < 0 || raw_close(plain) || raw_close(longest) ||
        kernel_call(__NR_symlinkat, (long)"plain", fd, (long)"link", 0, 0, 0))
        return 32;

    struct entry_reference expected[] = {
        {.name = "."}, {.name = ".."}, {.name = "sub"},
        {.name = "plain"}, {.name = "link"}, {.name = long_name}
    };
    enum { count = sizeof expected / sizeof expected[0] };
    if (!raw_directory_reference(expected, count))
        return 33;
    DIR *dir = opendir("entries");
    if (!dir)
        return 34;
    unsigned seen = 0;
    for (int i = 0; i < count; ++i) {
        errno = TEST_ERRNO;
        struct dirent *entry = readdir(dir);
        if (!entry || errno != TEST_ERRNO || !bounded_name(entry->d_name, sizeof entry->d_name))
            return 35;
        int index = name_index(expected, count, entry->d_name);
        if (index < 0 || (seen & (1U << index)) || entry->d_ino != expected[index].inode ||
            entry->d_reclen != expected[index].length || entry->d_type != expected[index].type)
            return 36;
        seen |= 1U << index;
    }
    errno = TEST_ERRNO;
    if (seen != (1U << count) - 1 || readdir(dir) || errno != TEST_ERRNO ||
        readdir(dir) || errno != TEST_ERRNO)
        return 37;
    if (closedir(dir) || kernel_call(__NR_unlinkat, fd, (long)long_name, 0, 0, 0, 0))
        return 38;
    return raw_close(fd) || raw_unlink("entries/plain", 0) || raw_unlink("entries/link", 0) ||
           raw_unlink("entries/sub", K_AT_REMOVEDIR) ||
           raw_unlink("entries", K_AT_REMOVEDIR) ? 39 : 0;
}

static void numbered_name(char name[9], unsigned index)
{
    name[5] = (char)('0' + index / 100);
    name[6] = (char)('0' + index / 10 % 10);
    name[7] = (char)('0' + index % 10);
}

static int readdir_refill(void)
{
    enum { count = 150 };
    unsigned char seen[count] = {0};
    if (raw_mkdir("many", 0700))
        return 90;
    int fd = (int)raw_open(AT_FDCWD, "many", O_RDONLY | O_DIRECTORY, 0);
    if (fd < 0)
        return 91;
    char name[9] = "item-000";
    for (unsigned i = 0; i < count; ++i) {
        numbered_name(name, i);
        int item = (int)raw_open(fd, name, O_WRONLY | O_CREAT | O_EXCL, 0600);
        if (item < 0 || raw_close(item))
            return 92;
    }
    DIR *dir = opendir("many");
    if (!dir)
        return 93;
    unsigned dots = 0;
    for (unsigned i = 0; i < count + 2; ++i) {
        errno = TEST_ERRNO;
        struct dirent *entry = readdir(dir);
        if (!entry || errno != TEST_ERRNO)
            return 94;
        const char *got = entry->d_name;
        if (same_text(got, ".") || same_text(got, "..")) {
            unsigned bit = got[1] == '.' ? 2 : 1;
            if (dots & bit)
                return 95;
            dots |= bit;
            continue;
        }
        if (got[0] != 'i' || got[1] != 't' || got[2] != 'e' || got[3] != 'm' || got[4] != '-')
            return 96;
        unsigned index = 0;
        for (unsigned digit = 5; digit < 8; ++digit) {
            if (got[digit] < '0' || got[digit] > '9')
                return 97;
            index = index * 10 + (unsigned)(got[digit] - '0');
        }
        if (got[8] != '\0' || index >= count || seen[index])
            return 98;
        seen[index] = 1;
    }
    errno = TEST_ERRNO;
    if (dots != 3 || readdir(dir) || errno != TEST_ERRNO || closedir(dir))
        return 99;
    for (unsigned i = 0; i < count; ++i) {
        numbered_name(name, i);
        if (!seen[i] || kernel_call(__NR_unlinkat, fd, (long)name, 0, 0, 0, 0))
            return 100;
    }
    return raw_close(fd) || raw_unlink("many", K_AT_REMOVEDIR) ? 101 : 0;
}

static int opendir_case(void)
{
    errno = TEST_ERRNO;
    DIR *dir = opendir(".");
    if (!dir || errno != TEST_ERRNO)
        return 40;
    int fd = dirfd(dir);
    if (fd < 0 || raw_fcntl(fd, K_F_GETFD, 0) != K_FD_CLOEXEC || closedir(dir))
        return 41;
    if (opendir("missing") || errno != ENOENT)
        return 42;
    int plain = (int)raw_open(AT_FDCWD, "plain", O_RDWR | O_CREAT | O_EXCL, 0600);
    if (plain < 0 || raw_close(plain))
        return 43;
    if (opendir("plain") || errno != ENOTDIR)
        return 44;
    return raw_unlink("plain", 0) ? 45 : 0;
}

static int fdopendir_case(void)
{
    int fd = (int)raw_open(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY, 0);
    if (fd < 0 || raw_fcntl(fd, K_F_GETFD, 0))
        return 50;
    errno = TEST_ERRNO;
    DIR *dir = fdopendir(fd);
    if (!dir || errno != TEST_ERRNO || dirfd(dir) != fd)
        return 51;
#ifndef OA_PHASE6_HOST
    if (raw_fcntl(fd, K_F_GETFD, 0) != K_FD_CLOEXEC)
        return 52;
#endif
    if (closedir(dir) || raw_fcntl(fd, K_F_GETFD, 0) != -EBADF)
        return 53;
    int plain = (int)raw_open(AT_FDCWD, "plain", O_RDWR | O_CREAT | O_EXCL, 0600);
    if (plain < 0)
        return 54;
    if (fdopendir(plain) || errno != ENOTDIR || raw_fcntl(plain, K_F_GETFD, 0))
        return 55;
    if (fdopendir(-1) || errno != EBADF)
        return 56;
#ifndef OA_PHASE6_HOST
    int path_only = (int)raw_open(AT_FDCWD, ".", O_PATH | O_DIRECTORY, 0);
    if (path_only < 0)
        return 57;
    errno = 0;
    if (fdopendir(path_only) || (errno != EBADF && errno != EINVAL) ||
        raw_fcntl(path_only, K_F_GETFD, 0) || raw_close(path_only))
        return 58;
#endif
    return raw_close(plain) || raw_unlink("plain", 0) ? 59 : 0;
}

static int dirfd_case(void)
{
    int fd = (int)raw_open(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY, 0);
    DIR *dir = fd < 0 ? NULL : fdopendir(fd);
    if (!dir)
        return 60;
    errno = TEST_ERRNO;
    if (dirfd(dir) != fd || errno != TEST_ERRNO)
        return 61;
    return closedir(dir) ? 62 : 0;
}

static int closedir_case(void)
{
    int fd = (int)raw_open(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY, 0);
    DIR *dir = fd < 0 ? NULL : fdopendir(fd);
    if (!dir)
        return 70;
    errno = TEST_ERRNO;
    if (closedir(dir) || errno != TEST_ERRNO || raw_fcntl(fd, K_F_GETFD, 0) != -EBADF)
        return 71;
    return 0;
}

static int readdir_error(void)
{
    int fd = (int)raw_open(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY, 0);
    DIR *dir = fd < 0 ? NULL : fdopendir(fd);
    if (!dir || raw_close(fd))
        return 80;
    errno = 0;
    if (readdir(dir) || errno != EBADF)
        return 81;
    return closedir(dir) == -1 && errno == EBADF ? 0 : 82;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    const char *mode = argv[1];
    if (same_text(mode, "readdir")) return readdir_case();
    if (same_text(mode, "readdir-refill")) return readdir_refill();
    if (same_text(mode, "opendir")) return opendir_case();
    if (same_text(mode, "fdopendir")) return fdopendir_case();
    if (same_text(mode, "dirfd")) return dirfd_case();
    if (same_text(mode, "closedir")) return closedir_case();
    if (same_text(mode, "readdir-error")) return readdir_error();
    return 2;
}
