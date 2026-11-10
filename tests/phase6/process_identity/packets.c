#include "identity.h"

struct packet { uint64_t selector, seed; };
struct observation {
    uint64_t role, matches, self_valid, parent_valid, expected_parent;
    uint64_t errno_before, errno_after, identities_stable;
    uint32_t pid, ppid;
};
_Static_assert(sizeof(struct packet) == 16 && sizeof(struct observation) == 72, "LP64 packet widths");

typedef pid_t (*query_fn)(void);

static int transfer(int fd, void *bytes, size_t size, int output)
{
    size_t offset = 0;
    while (offset < size) {
        unsigned char *at = (unsigned char *)bytes + offset;
        long count = output ? raw_write(fd, at, size - offset) : raw_read(fd, at, size - offset);
        if (count == -EINTR)
            continue;
        if (count <= 0)
            return !count && !offset && !output ? 0 : -1;
        offset += (size_t)count;
    }
    return 1;
}

static int observe(query_fn query, int parent, unsigned role, long known_parent,
                   int sentinel, struct observation *result)
{
    long own = raw_identity(0), owner = raw_identity(1);
    if (own <= 0 || own > INT32_MAX || owner < 0 || owner > INT32_MAX)
        return 0;
    errno = sentinel;
    pid_t actual = query();
    int saved_errno = errno;
    long later_own = raw_identity(0), later_owner = raw_identity(1);
    *result = (struct observation) {
        .role = role,
        .matches = actual == (pid_t)(parent ? owner : own),
        .self_valid = own > 0 && own != owner,
        .parent_valid = owner >= 0,
        .expected_parent = !role || owner == known_parent,
        .errno_before = (uint64_t)sentinel,
        .errno_after = (uint64_t)saved_errno,
        .identities_stable = own == later_own && owner == later_owner,
        .pid = (uint32_t)own,
        .ppid = (uint32_t)owner,
    };
    return 1;
}

static void send_observation(int fd, query_fn query, int parent, unsigned role,
                             long known_parent, int sentinel)
{
    struct observation result;
    int passed = observe(query, parent, role, known_parent, sentinel, &result) &&
                 transfer(fd, &result, sizeof result, 1) == 1;
    _exit(passed ? 0 : 81);
}

static int delegated(query_fn query, int parent, unsigned role, int sentinel,
                     struct observation *result)
{
    int descriptors[2];
    if (kernel_call(__NR_pipe2, (long)descriptors, 0, 0, 0, 0, 0))
        return 0;
    long creator = raw_identity(0);
    long child = raw_fork_process();
    if (child < 0) {
        raw_close(descriptors[0]);
        raw_close(descriptors[1]);
        return 0;
    }
    if (!child) {
        raw_close(descriptors[0]);
        if (role == 1)
            send_observation(descriptors[1], query, parent, role, creator, sentinel);
        long intermediate = raw_identity(0);
        long grandchild = raw_fork_process();
        if (grandchild < 0)
            _exit(82);
        if (!grandchild)
            send_observation(descriptors[1], query, parent, role, intermediate, sentinel);
        raw_close(descriptors[1]);
        _exit(raw_wait_status(grandchild) == 0 ? 0 : 83);
    }
    raw_close(descriptors[1]);
    int received = transfer(descriptors[0], result, sizeof *result, 0);
    raw_close(descriptors[0]);
    int child_status = raw_wait_status(child);
    return received == 1 && child_status == 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    int parent = same_text(argv[1], "getppid");
    if (!parent && !same_text(argv[1], "getpid"))
        return 91;
    query_fn query = parent ? getppid : getpid;
    struct packet packet;
    int received;
    while ((received = transfer(STDIN_FILENO, &packet, sizeof packet, 0)) == 1) {
        unsigned choice = (unsigned)(packet.selector & 31);
        unsigned role = choice == 0 ? 2 : choice < 4 ? 1 : 0;
        int sentinel = 1 + (int)(packet.seed & 0x3fffffff);
        struct observation result;
        int valid = role ? delegated(query, parent, role, sentinel, &result)
                         : observe(query, parent, role, 0, sentinel, &result);
        if (!valid || transfer(STDOUT_FILENO, &result, sizeof result, 1) != 1)
            return 92;
    }
    return received < 0 ? 93 : 0;
}
