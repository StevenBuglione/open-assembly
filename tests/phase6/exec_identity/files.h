#ifndef OA_EXEC_IDENTITY_FILES_H
#define OA_EXEC_IDENTITY_FILES_H

#include "fixture.h"

static const char fixture_root[] = "exec-packet-root";
static const char *const images[] = {"first/tool", "later/tool", "tool"};

static inline long change_dir(const char *path)
{
    return kernel_call(__NR_chdir, (long)path, 0, 0, 0, 0, 0);
}

static inline int install_image(int source, const char *path)
{
    int target = (int)raw_open(AT_FDCWD, path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0700);
    if (target < 0)
        return 0;
    int copied = raw_seek(source, 0, SEEK_SET) == 0;
    char data[16384];
    while (copied) {
        long count = raw_read(source, data, sizeof data);
        if (count == -EINTR)
            continue;
        if (!count)
            break;
        copied = count > 0 && write_all(target, data, (size_t)count);
    }
    return raw_close(target) == 0 && copied;
}

static inline int populate(int source)
{
    if (raw_mkdir("first", 0700) || raw_mkdir("later", 0700) || raw_mkdir("deny", 0700))
        return 0;
    for (size_t i = 0; i < sizeof images / sizeof *images; ++i)
        if (!install_image(source, images[i]))
            return 0;
    return kernel_call(__NR_linkat, AT_FDCWD, (long)"first/tool",
                       AT_FDCWD, (long)"first/only", 0, 0) == 0 &&
           kernel_call(__NR_symlinkat, (long)"loop", AT_FDCWD, (long)"first/loop", 0, 0, 0) == 0 &&
           make_file("deny/tool", "denied\n", 7, 0600) &&
           make_file("regular", "regular\n", 8, 0600) &&
           make_file("plain", "plain text\n", 11, 0700);
}

static inline int remove_entry(const char *path, int flags, int partial)
{
    long status = raw_unlink(path, flags);
    return status == 0 || (partial && status == -ENOENT);
}

static inline int remove_fixture(int parent, int partial)
{
    static const char *const files[] = {
        "first/only", "first/loop", "deny/tool", "regular", "plain",
        "first/tool", "later/tool", "tool",
    };
    int cleaned = 1;
    for (size_t i = 0; i < sizeof files / sizeof *files; ++i)
        cleaned &= remove_entry(files[i], 0, partial);
    cleaned &= remove_entry("first", K_AT_REMOVEDIR, partial);
    cleaned &= remove_entry("later", K_AT_REMOVEDIR, partial);
    cleaned &= remove_entry("deny", K_AT_REMOVEDIR, partial);
    if (kernel_call(__NR_fchdir, parent, 0, 0, 0, 0, 0))
        return 0;
    return remove_entry(fixture_root, K_AT_REMOVEDIR, 0) && cleaned;
}

#endif
