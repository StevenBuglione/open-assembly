#include "../kernel_abi.h"
#include <libgen.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>

/* Linux UAPI asm-generic/ioctls.h and asm-generic/termbits.h. */
enum { K_TCGETS = 0x5401, K_FIONREAD = 0x541B, K_FIOCLEX = 0x5451 };

static int chmod_case(void)
{
    int fd = (int)raw_open(AT_FDCWD, "plain", O_WRONLY | O_CREAT | O_EXCL, 0700);
    if (fd < 0 || kernel_call(__NR_symlinkat, (long)"plain", AT_FDCWD, (long)"link", 0, 0, 0))
        return 11;
    errno = TEST_ERRNO;
    struct kernel_stat sb;
    if (chmod("link", 0642) || errno != TEST_ERRNO || raw_fstat(fd, &sb) ||
        (sb.mode & 0777) != 0642)
        return 12;
    if (chmod("missing", 0600) != -1 || errno != ENOENT)
        return 13;
    return raw_close(fd) || raw_unlink("link", 0) || raw_unlink("plain", 0) ? 14 : 0;
}

static int umask_case(void)
{
    if (kernel_call(__NR_umask, 0022, 0, 0, 0, 0, 0) < 0)
        return 20;
    errno = TEST_ERRNO;
    if (umask(0077) != 0022 || errno != TEST_ERRNO)
        return 21;
    int fd = (int)raw_open(AT_FDCWD, "created", O_WRONLY | O_CREAT | O_EXCL, 0666);
    struct kernel_stat sb;
    if (fd < 0 || raw_fstat(fd, &sb) || (sb.mode & 0777) != 0600)
        return 22;
    if (kernel_call(__NR_umask, 0022, 0, 0, 0, 0, 0) != 0077)
        return 23;
    return raw_close(fd) || raw_unlink("created", 0) ? 24 : 0;
}

static int getcwd_case(void)
{
    char want[4096];
    long size = kernel_call(__NR_getcwd, (long)want, sizeof want, 0, 0, 0, 0);
    if (size < 2 || size > (long)sizeof want || want[0] != '/' || want[size - 1] != '\0')
        return 30;
    char got[4097];
    got[size] = 'X';
    errno = TEST_ERRNO;
    if (getcwd(got, (size_t)size) != got || errno != TEST_ERRNO ||
        got[size] != 'X' || !same_text(got, want))
        return 31;
    char *owned = getcwd(NULL, 0);
    if (!owned || !same_text(owned, want))
        return 32;
    free(owned);
    owned = getcwd(NULL, (size_t)size);
    if (!owned || !same_text(owned, want))
        return 33;
    free(owned);
    if (getcwd(got, 1) || errno != ERANGE || getcwd(got, 0) || errno != EINVAL)
        return 34;
    return 0;
}

static int ioctl_case(void)
{
    int ends[2];
    if (kernel_call(__NR_pipe2, (long)ends, 0, 0, 0, 0, 0) || raw_write(ends[1], "abc", 3) != 3)
        return 41;
    errno = TEST_ERRNO;
    int pending = -1;
    if (ioctl(ends[0], K_FIONREAD, &pending) || pending != 3 || errno != TEST_ERRNO)
        return 42;
    if (ioctl(ends[0], K_FIOCLEX) || raw_fcntl(ends[0], K_F_GETFD, 0) != K_FD_CLOEXEC)
        return 43;
    if (ioctl(-1, K_FIONREAD, &pending) != -1 || errno != EBADF)
        return 44;
    return raw_close(ends[0]) || raw_close(ends[1]) ? 45 : 0;
}

static int isatty_case(void)
{
    int fd = (int)raw_open(AT_FDCWD, "/dev/null", O_RDONLY, 0);
    if (fd < 0)
        return 50;
    errno = TEST_ERRNO;
    if (isatty(fd) || errno != ENOTTY || raw_close(fd))
        return 51;
    if (isatty(-1) || errno != EBADF)
        return 52;
    fd = (int)raw_open(AT_FDCWD, "/dev/ptmx", O_RDWR | O_NOCTTY, 0);
    if (fd < 0)
        return 53;
    unsigned char termios[64];
    if (kernel_call(__NR_ioctl, fd, K_TCGETS, (long)termios, 0, 0, 0))
        return 54;
    errno = TEST_ERRNO;
    return isatty(fd) != 1 || errno != TEST_ERRNO || raw_close(fd) ? 55 : 0;
}

static int readlink_case(void)
{
    if (kernel_call(__NR_symlinkat, (long)"some/target", AT_FDCWD, (long)"link", 0, 0, 0))
        return 60;
    char output[] = "ABCDEFGHIJKLMN";
    errno = TEST_ERRNO;
    if (readlink("link", output + 1, 4) != 4 || errno != TEST_ERRNO ||
        !same_text(output, "AsomeFGHIJKLMN"))
        return 61;
    if (readlink("link", output, sizeof output) != 11 ||
        !same_text(output, "some/targetLMN"))
        return 62;
    if (readlink("missing", output, sizeof output) != -1 || errno != ENOENT)
        return 63;
    return raw_unlink("link", 0) ? 64 : 0;
}

static int dirname_case(void)
{
    char rooted[] = "/a///b//";
    char relative[] = "file";
    char slashes[] = "////";
    char empty[] = "";
    errno = TEST_ERRNO;
    char *got = dirname(rooted);
    if (!got || !same_text(got, "/a") || errno != TEST_ERRNO)
        return 71;
    if (!same_text(dirname(relative), ".") || !same_text(dirname(slashes), "/") ||
        !same_text(dirname(empty), ".") || !same_text(dirname(NULL), "."))
        return 72;
    return 0;
}

static int strdup_case(void)
{
    char input[] = "one";
    errno = TEST_ERRNO;
    char *copy = strdup(input);
    if (!copy || copy == input || !same_text(copy, "one") || errno != TEST_ERRNO)
        return 81;
    input[0] = 'X';
    copy[1] = 'Q';
    if (!same_text(input, "Xne") || !same_text(copy, "oQe"))
        return 82;
    free(copy);
    copy = strdup("");
    if (!copy || *copy)
        return 83;
    free(copy);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    if (same_text(argv[1], "chmod")) return chmod_case();
    if (same_text(argv[1], "umask")) return umask_case();
    if (same_text(argv[1], "getcwd")) return getcwd_case();
    if (same_text(argv[1], "ioctl")) return ioctl_case();
    if (same_text(argv[1], "isatty")) return isatty_case();
    if (same_text(argv[1], "readlink")) return readlink_case();
    if (same_text(argv[1], "dirname")) return dirname_case();
    if (same_text(argv[1], "strdup")) return strdup_case();
    return 2;
}
