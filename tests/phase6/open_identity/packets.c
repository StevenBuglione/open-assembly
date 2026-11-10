#include "../kernel_abi.h"
#include <stdint.h>
#include <sys/stat.h>

enum { TYPE_MASK = 0170000, REGULAR = 0100000 };
static const char directory_name[] = "open-packet-dir";
static const char cwd_source[] = "open-packet-source";
static const char inner_source[] = "open-packet-dir/source";
static const char truncate_name[] = "open-packet-truncate";
static const unsigned char cwd_bytes[] = {0x31, 0, 0x82, 0xf0, 'C', 3, 5, 7};
static const unsigned char inner_bytes[] = {0x54, 0xa4, 0, 0xff, 'D', 9, 4, 2};

struct fixture { int directory, regular, temporary; };
struct packet { uint64_t selector, payload; };
struct result { int64_t status; uint64_t error, type_mode, fdflags, flags, size, links, data; };
_Static_assert(sizeof(struct packet) == 16 && sizeof(struct result) == 64, "LP64 packet widths");

static int seed(const char *path, const unsigned char *bytes)
{
    long fd = raw_open(AT_FDCWD, path, O_WRONLY | O_CREAT | O_EXCL, 0600);
    if (fd < 0)
        return 0;
    long written = raw_write((int)fd, bytes, 8);
    return !raw_close((int)fd) && written == 8;
}

static int setup(struct fixture *fixture)
{
    if (kernel_call(__NR_umask, 0, 0, 0, 0, 0, 0) < 0 || raw_mkdir(directory_name, 0700) ||
        !seed(cwd_source, cwd_bytes) || !seed(inner_source, inner_bytes))
        return 0;
    fixture->directory = (int)raw_open(AT_FDCWD, directory_name, O_RDONLY | O_DIRECTORY, 0);
    fixture->regular = (int)raw_open(AT_FDCWD, cwd_source, O_RDONLY, 0);
    fixture->temporary = (int)raw_open(AT_FDCWD, "/dev/shm", O_RDONLY | O_DIRECTORY, 0);
    return fixture->directory >= 0 && fixture->regular >= 0 && fixture->temporary >= 0;
}

static int finish(const struct fixture *fixture)
{
    return !raw_close(fixture->temporary) && !raw_close(fixture->regular) &&
           !raw_close(fixture->directory) && !raw_unlink(inner_source, 0) &&
           !raw_unlink(cwd_source, 0) && !raw_unlink(directory_name, K_AT_REMOVEDIR);
}

static void describe(int descriptor, struct result *out)
{
    struct kernel_stat info;
    if (raw_fstat(descriptor, &info)) {
        out->type_mode = UINT64_MAX;
        return;
    }
    out->type_mode = info.mode & TYPE_MASK;
    long status = raw_fcntl(descriptor, K_F_GETFL, 0);
    out->fdflags = (uint64_t)raw_fcntl(descriptor, K_F_GETFD, 0);
    out->flags = status < 0 ? (uint64_t)status : (uint64_t)(status & (O_ACCMODE | O_APPEND | O_NONBLOCK));
    if (out->type_mode == REGULAR) {
        out->type_mode |= info.mode & 07777;
        out->size = info.size;
        out->links = info.links;
        if (status >= 0 && (status & O_ACCMODE) != O_WRONLY) {
            unsigned char bytes[8] = {0};
            long read_count = kernel_call(__NR_pread64, descriptor, (long)bytes, sizeof bytes, 0, 0, 0);
            if (read_count < 0) {
                out->data = (uint64_t)read_count;
            } else {
                for (unsigned i = 0; i < sizeof bytes; ++i)
                    out->data |= (uint64_t)bytes[i] << (i * 8);
            }
        }
    }
}

static int observe(const struct fixture *fixture, int at, const struct packet *packet, struct result *out)
{
    unsigned choice = (unsigned)(packet->selector & 15);
    int inner = (packet->selector & 16) != 0;
    int directory = at && inner ? fixture->directory : AT_FDCWD;
    const char *path = inner ? (at ? "source" : inner_source) : cwd_source;
    int flags = O_RDONLY | (packet->selector & 32 ? O_CLOEXEC : 0);
    const char *cleanup = NULL;
    switch (choice) {
    case 0: break;
    case 1: path = "open-packet-missing"; break;
    case 2:
        path = at && inner ? "." : directory_name;
        flags |= O_DIRECTORY;
        break;
    case 3: flags |= O_DIRECTORY; break;
    case 4: flags |= O_CREAT | O_EXCL | O_RDWR; break;
    case 5:
        cleanup = inner ? "open-packet-dir/new" : "open-packet-new";
        path = at && inner ? "new" : cleanup;
        flags |= O_CREAT | O_EXCL | O_RDWR;
        break;
    case 6:
        path = cleanup = truncate_name;
        directory = AT_FDCWD;
        flags |= O_RDWR | O_TRUNC;
        if (!seed(path, cwd_bytes))
            return 0;
        break;
    case 7:
        path = "/dev/null";
        directory = -1;
        break;
    case 8:
        path = at ? cwd_source : "open-packet-missing";
        directory = -1;
        break;
    case 9:
        path = at ? "child" : "open-packet-source/child";
        directory = fixture->regular;
        break;
    case 10:
        path = at ? "." : "/dev/shm";
        directory = fixture->temporary;
        flags |= O_TMPFILE | O_RDWR;
        break;
    case 11: path = ""; break;
    case 12: flags |= O_APPEND | O_RDWR; break;
    case 13: flags |= O_NONBLOCK; break;
    case 14:
        path = inner_source;
        directory = AT_FDCWD;
        break;
    default:
        path = "open-packet-dir/../open-packet-source";
        directory = AT_FDCWD;
        break;
    }

    unsigned mask = (unsigned)((packet->selector >> 8) & 077);
    mode_t mode = (mode_t)((packet->payload >> 16) & 0777);
    long old_mask = kernel_call(__NR_umask, mask, 0, 0, 0, 0, 0);
    if (old_mask < 0)
        return 0;
    int takes_mode = (flags & O_CREAT) || (flags & O_TMPFILE) == O_TMPFILE;
    errno = 0x600 + (int)((packet->selector >> 32) & 255);
    int descriptor;
    if (at)
        descriptor = takes_mode ? openat(directory, path, flags, mode) : openat(directory, path, flags);
    else
        descriptor = takes_mode ? open(path, flags, mode) : open(path, flags);
    out->status = descriptor < 0 ? descriptor : 0;
    out->error = (uint64_t)errno;
    if (kernel_call(__NR_umask, old_mask, 0, 0, 0, 0, 0) != (long)mask)
        return 0;
    if (descriptor >= 0) {
        describe(descriptor, out);
        if (raw_close(descriptor))
            return 0;
    }
    long removed = cleanup ? raw_unlink(cleanup, 0) : 0;
    return removed == 0 || removed == -ENOENT;
}

static int transfer(int fd, void *memory, size_t size, int output)
{
    size_t offset = 0;
    while (offset < size) {
        unsigned char *bytes = (unsigned char *)memory + offset;
        long count = output ? raw_write(fd, bytes, size - offset) : raw_read(fd, bytes, size - offset);
        if (count == -EINTR)
            continue;
        if (count <= 0)
            return !count && !offset && !output ? 0 : -1;
        offset += (size_t)count;
    }
    return 1;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    int at = same_text(argv[1], "openat");
    if (!at && !same_text(argv[1], "open"))
        return 91;
    struct fixture fixture;
    if (!setup(&fixture))
        return 92;
    struct packet packet;
    int received;
    while ((received = transfer(STDIN_FILENO, &packet, sizeof packet, 0)) == 1) {
        struct result result = {0};
        if (!observe(&fixture, at, &packet, &result) ||
            transfer(STDOUT_FILENO, &result, sizeof result, 1) != 1)
            return 93;
    }
    return received < 0 || !finish(&fixture) ? 94 : 0;
}
