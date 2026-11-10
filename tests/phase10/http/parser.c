#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

extern unsigned __al_http_parse(const unsigned char *, size_t);
extern long __al_syscall(long, long, long, long, long, long, long);
struct aux_entry { unsigned long type, value; };
extern const struct aux_entry *const __al_auxv;

static int read_all(void *data, size_t size)
{
    unsigned char *cursor = data;
    size_t consumed = 0;
    while (consumed < size) {
        ssize_t got = read(STDIN_FILENO, cursor + consumed, size - consumed);
        if (!got)
            return consumed ? -1 : 0;
        if (got < 0) {
            if (errno != EINTR)
                return -1;
            continue;
        }
        consumed += (size_t)got;
    }
    return 1;
}

int main(int argc, char **argv)
{
    enum { SYS_MMAP = 9, SYS_MPROTECT = 10, SYS_MUNMAP = 11, MAX_LENGTH = 16384 };
    enum { PROT_READ = 1, PROT_WRITE = 2, MAP_PRIVATE_ANONYMOUS = 0x22, AT_PAGESZ = 6 };
    if (argc != 2 || (strcmp(argv[1], "left") && strcmp(argv[1], "right")))
        return 90;
    int right = !strcmp(argv[1], "right");
    size_t page = 0;
    for (const struct aux_entry *entry = __al_auxv; entry->type; ++entry) {
        if (entry->type == AT_PAGESZ)
            page = entry->value;
    }
    if (!page)
        return 91;
    size_t available = (MAX_LENGTH + page - 1) / page * page;
    size_t mapping_size = available + 2 * page;
    long region = __al_syscall(SYS_MMAP, 0, mapping_size, 0, MAP_PRIVATE_ANONYMOUS, -1, 0);
    if (region < 0)
        return 92;
    unsigned char *accessible = (void *)(region + page);
    errno = EDOM;
    if (__al_http_parse(NULL, 0) || errno != EDOM)
        return 93;
    uint32_t length;
    int input;
    while ((input = read_all(&length, sizeof length)) == 1) {
        if (length > MAX_LENGTH ||
            __al_syscall(SYS_MPROTECT, (long)accessible, available, PROT_READ | PROT_WRITE, 0, 0, 0))
            return 94;
        unsigned char *data = accessible + (right ? available - length : 0);
        if (read_all(data, length) != 1 ||
            __al_syscall(SYS_MPROTECT, (long)accessible, available, PROT_READ, 0, 0, 0))
            return 95;
        errno = EDOM;
        uint32_t result = __al_http_parse(data, length);
        if (errno != EDOM || write(STDOUT_FILENO, &result, sizeof result) != sizeof result)
            return 96;
    }
    if (input || __al_syscall(SYS_MUNMAP, region, mapping_size, 0, 0, 0, 0))
        return 97;
    return 0;
}
