#include "../kernel_abi.h"

#include <stdint.h>
#include <stdlib.h>

struct stimulus { uint64_t mode, value; };
struct observed {
    int64_t result, error;
    uint64_t scenario, extent, length, bytes, effect, sentinel;
};
_Static_assert(sizeof(struct stimulus) == 16 && sizeof(struct observed) == 64,
               "Linux LP64 packet widths");

enum { GUARD = 0xa5 };

static int read_row(struct stimulus *input)
{
    size_t done = 0;
    while (done < sizeof *input) {
        long count = raw_read(STDIN_FILENO, (char *)input + done, sizeof *input - done);
        if (count == -EINTR)
            continue;
        if (count < 0 || (!count && done))
            return -1;
        if (!count)
            return 0;
        done += (size_t)count;
    }
    return 1;
}

static int write_row(const struct observed *output)
{
    size_t done = 0;
    while (done < sizeof *output) {
        long count = raw_write(STDOUT_FILENO, (const char *)output + done, sizeof *output - done);
        if (count == -EINTR)
            continue;
        if (count <= 0)
            return 0;
        done += (size_t)count;
    }
    return 1;
}

static uint64_t digest(const unsigned char *data, size_t count)
{
    uint64_t value = 0;
    for (size_t i = 0; i < count; ++i)
        value = value * 257 + data[i];
    return value;
}

static void fill(unsigned char *data, size_t count, unsigned char value)
{
    for (size_t i = 0; i < count; ++i)
        data[i] = value;
}

static int matches(const unsigned char *data, size_t count, const unsigned char *payload,
                   size_t length)
{
    for (size_t i = 0; i < count; ++i) {
        unsigned char want = i > 0 && i <= length ? payload[i - 1] : GUARD;
        if (data[i] != want)
            return 0;
    }
    return 1;
}

static long change_dir(const char *path)
{
    return kernel_call(__NR_chdir, (long)path, 0, 0, 0, 0, 0);
}

static long restore_dir(int fd)
{
    return kernel_call(__NR_fchdir, fd, 0, 0, 0, 0, 0);
}

static int cwd_row(struct stimulus input, struct observed *output)
{
    unsigned mode = (unsigned)(input.mode % 7);
    size_t length = 1 + (size_t)(input.value & 15);
    char component[17];
    for (size_t i = 0; i < length; ++i)
        component[i] = (char)('a' + ((input.value >> (4 * i)) & 15));
    component[length] = 0;

    int parent = (int)raw_open(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0);
    if (parent < 0 || raw_mkdir(component, 0700) || change_dir(component))
        return 90;
    unsigned char expected[4096], buffer[4098];
    long absolute = kernel_call(__NR_getcwd, (long)expected, sizeof expected, 0, 0, 0, 0);
    if (absolute < (long)length + 2 || absolute > (long)sizeof expected ||
        expected[absolute - 1] || expected[absolute - length - 2] != '/' ||
        !same_text((char *)expected + absolute - length - 1, component))
        return 91;
    if (mode == 6 && kernel_call(__NR_unlinkat, parent, (long)component, K_AT_REMOVEDIR, 0, 0, 0))
        return 92;

    size_t size = (size_t)absolute, normalized_size = length + 1;
    int expected_error = TEST_ERRNO;
    if (mode == 1) {
        ++size;
        ++normalized_size;
    } else if (mode == 2) {
        --size;
        --normalized_size;
        expected_error = ERANGE;
    } else if (mode == 3 || mode == 4) {
        size = normalized_size = 0;
        if (mode == 3)
            expected_error = EINVAL;
    } else if (mode == 6) {
        expected_error = ENOENT;
    }
    int allocated = mode == 4 || mode == 5;
    fill(buffer, sizeof buffer, GUARD);
    errno = TEST_ERRNO;
    char *result = getcwd(allocated ? NULL : (char *)buffer + 1, size);
    int error = errno;
    int success = expected_error == TEST_ERRNO;
    if (!!result != success || error != expected_error ||
        (result && !allocated && result != (char *)buffer + 1))
        return 11;
    size_t written = !allocated && success ? (size_t)absolute : 0;
    if (!matches(buffer, sizeof buffer, expected, written) ||
        (allocated && result && !same_text(result, (char *)expected)))
        return 12;
    uint64_t contents = success ? digest((unsigned char *)result + absolute - length - 1, length) : 0;
    if (allocated && result)
        free(result);
    if (restore_dir(parent) || raw_close(parent) ||
        (mode != 6 && raw_unlink(component, K_AT_REMOVEDIR)))
        return 93;
    *output = (struct observed){success ? 0 : -1, error, mode, normalized_size,
                                success ? length : 0, contents, 1, TEST_ERRNO};
    return 0;
}

static long symlink_at(const char *target, const char *path)
{
    return kernel_call(__NR_symlinkat, (long)target, AT_FDCWD, (long)path, 0, 0, 0);
}

static int create(const char *path)
{
    return (int)raw_open(AT_FDCWD, path, O_CREAT | O_EXCL | O_RDWR | O_CLOEXEC, 0600);
}

static int link_row(struct stimulus input, struct observed *output)
{
    unsigned mode = (unsigned)(input.mode % 8);
    if (mode >= 3)
        ++mode;
    size_t length = 1 + (size_t)(input.value & 31);
    unsigned char target[33], buffer[66];
    for (size_t i = 0; i < length; ++i)
        target[i] = (unsigned char)(1 + (((input.value >> ((i % 8) * 8)) & 255) + 29 * i) % 255);
    target[length] = 0;
    const char *path = "link";
    size_t size = 64;
    int expected_error = TEST_ERRNO;
    int plain = mode == 4 || mode == 6;
    char oversized[4097];
    if (plain) {
        int fd = create("plain");
        if (fd < 0 || raw_close(fd))
            return 90;
    }
    if (mode <= 2 && symlink_at((const char *)target, "link"))
        return 90;
    switch (mode) {
    case 0:
        break;
    case 1:
        size = length > 1 ? 1 + (size_t)((input.value >> 8) % (length - 1)) : 1;
        break;
    case 2:
        size = length;
        break;
    case 4:
        path = "plain";
        expected_error = EINVAL;
        break;
    case 5:
        path = "missing";
        expected_error = ENOENT;
        break;
    case 6:
        path = "plain/child";
        expected_error = ENOTDIR;
        break;
    case 7:
        if (symlink_at("loop", "loop"))
            return 90;
        path = "loop/child";
        expected_error = ELOOP;
        break;
    case 8:
        fill((unsigned char *)oversized, sizeof oversized - 1, 'x');
        oversized[sizeof oversized - 1] = 0;
        path = oversized;
        expected_error = ENAMETOOLONG;
        break;
    }
    fill(buffer, sizeof buffer, GUARD);
    errno = TEST_ERRNO;
    long result = readlink(path, (char *)buffer + 1, size);
    int error = errno;
    size_t written = size < length ? size : length;
    int success = expected_error == TEST_ERRNO;
    if (result != (success ? (long)written : -1) || error != expected_error)
        return 21;
    if (!matches(buffer, sizeof buffer, target, success ? written : 0))
        return 22;
    if ((plain && raw_unlink("plain", 0)) || (mode <= 2 && raw_unlink("link", 0)) ||
        (mode == 7 && raw_unlink("loop", 0)))
        return 93;
    *output = (struct observed){result, error, mode, size, success ? written : 0,
                                success ? digest(buffer + 1, written) : 0, 1, TEST_ERRNO};
    return 0;
}

static long path_status(const char *path)
{
    struct kernel_stat stat;
    return raw_stat(AT_FDCWD, path, K_AT_SYMLINK_NOFOLLOW, &stat);
}

static int remove_row(struct stimulus input, struct observed *output, int directory)
{
    unsigned mode = (unsigned)(input.mode % 7);
    const char *path = directory ? "directory" : "plain";
    int expected_error = TEST_ERRNO;
    int with_child = directory && mode == 1;
    int retained_file = directory || mode != 0;
    int retained_link = directory || mode != 1;
    int retained_dir = !directory || (mode != 0 && mode != 6);
    int fd = create("plain");
    unsigned char byte = (unsigned char)input.value, actual = 0;
    struct kernel_stat initial, final;
    if (fd < 0 || raw_write(fd, &byte, 1) != 1 || raw_fstat(fd, &initial) || initial.links != 1 ||
        raw_mkdir("directory", 0700) || symlink_at(directory ? "directory" : "plain", "link"))
        return 90;
    if (with_child) {
        int child = create("directory/child");
        if (child < 0 || raw_close(child))
            return 91;
    }
    switch (mode) {
    case 0:
        break;
    case 1:
        if (directory)
            expected_error = ENOTEMPTY;
        else
            path = "link";
        break;
    case 2:
        path = directory ? "plain" : "directory";
        expected_error = directory ? ENOTDIR : EISDIR;
        break;
    case 3:
        path = "missing";
        expected_error = ENOENT;
        break;
    case 4:
        path = directory ? "link" : "plain/child";
        expected_error = ENOTDIR;
        break;
    case 5:
        path = directory ? "." : "plain/";
        expected_error = directory ? EINVAL : ENOTDIR;
        break;
    case 6:
        if (directory)
            path = "./directory/";
        else {
            path = "./missing";
            expected_error = ENOENT;
        }
        break;
    }
    errno = TEST_ERRNO;
    int result = directory ? rmdir(path) : unlink(path);
    int error = errno;
    if (result != (expected_error == TEST_ERRNO ? 0 : -1) || error != expected_error)
        return 31;
    long statuses[4] = {path_status("plain"), path_status("link"),
                        path_status("directory"), path_status("directory/child")};
    const int retained[] = {retained_file, retained_link, retained_dir, with_child};
    uint64_t effect = 0;
    for (unsigned i = 0; i < sizeof retained / sizeof *retained; ++i) {
        if (statuses[i] != (retained[i] ? 0 : -ENOENT))
            return 32;
        if (statuses[i] == 0)
            effect |= UINT64_C(1) << i;
    }
    if (raw_fstat(fd, &final) || final.inode != initial.inode ||
        final.device != initial.device || final.links != (uint64_t)retained_file ||
        raw_seek(fd, 0, SEEK_SET) != 0 || raw_read(fd, &actual, 1) != 1 || actual != byte)
        return 33;
    if (raw_close(fd) || (with_child && raw_unlink("directory/child", 0)) ||
        (retained_link && raw_unlink("link", 0)) ||
        (retained_dir && raw_unlink("directory", K_AT_REMOVEDIR)) ||
        (retained_file && raw_unlink("plain", 0)))
        return 93;
    *output = (struct observed){result, error, mode, final.links, 1, actual, effect, TEST_ERRNO};
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    enum { CWD, LINK, REMOVE_FILE, REMOVE_DIR } operation;
    if (same_text(argv[1], "getcwd"))
        operation = CWD;
    else if (same_text(argv[1], "readlink"))
        operation = LINK;
    else if (same_text(argv[1], "unlink"))
        operation = REMOVE_FILE;
    else if (same_text(argv[1], "rmdir"))
        operation = REMOVE_DIR;
    else
        return 90;

    const char *root = "path-packet-root";
    int parent = (int)raw_open(AT_FDCWD, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC, 0);
    if (parent < 0 || raw_mkdir(root, 0700) || change_dir(root))
        return 95;
    struct stimulus input;
    int received;
    while ((received = read_row(&input)) > 0) {
        struct observed output;
        int status;
        if (operation == CWD)
            status = cwd_row(input, &output);
        else if (operation == LINK)
            status = link_row(input, &output);
        else
            status = remove_row(input, &output, operation == REMOVE_DIR);
        if (status)
            return status;
        if (!write_row(&output))
            return 96;
    }
    if (received < 0 || restore_dir(parent) || raw_close(parent) ||
        raw_unlink(root, K_AT_REMOVEDIR))
        return 97;
    return 0;
}
