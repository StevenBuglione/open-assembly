#include "kernel_abi.h"
#include <dirent.h>

enum fault_kind {
    none, short_header, zero_length, length_beyond_buffer, missing_nul,
    name_too_long, pipe_no_descriptors
};

static enum fault_kind armed;
static int directory_fd;
static unsigned injected;

long __real___al_syscall(long, long, long, long, long, long, long);

long __wrap___al_syscall(long nr, long a1, long a2, long a3, long a4, long a5, long a6)
{
    if (armed == pipe_no_descriptors && (nr == __NR_pipe || nr == __NR_pipe2)) {
        armed = none;
        ++injected;
        return -EMFILE;
    }
    if (armed >= short_header && armed <= name_too_long &&
        nr == __NR_getdents64 && a1 == directory_fd && a2 && a3 >= 280) {
        enum fault_kind kind = armed;
        armed = none;
        ++injected;

        unsigned short length = 24;
        unsigned returned = 24;
        switch (kind) {
        case short_header: returned = 19; length = 19; break;
        case zero_length: length = 0; break;
        case length_beyond_buffer: length = 32; break;
        case name_too_long: returned = 280; length = 280; break;
        default: break;
        }
        unsigned char *entry = (unsigned char *)a2;
        for (unsigned i = 0; i < returned; ++i)
            entry[i] = 0;
        entry[0] = 17;
        entry[16] = (unsigned char)length;
        entry[17] = (unsigned char)(length >> 8);
        entry[18] = DT_REG;
        if (kind == missing_nul || kind == name_too_long) {
            unsigned limit = kind == missing_nul ? returned : 275;
            for (unsigned i = 19; i < limit; ++i)
                entry[i] = 'x';
        } else if (returned > 19) {
            entry[19] = 'x';
        }
        return returned;
    }
    return __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
}

static int bad_records(void)
{
    for (enum fault_kind kind = short_header; kind <= name_too_long; ++kind) {
        DIR *dir = opendir(".");
        if (!dir)
            return 20;
        directory_fd = dirfd(dir);
        if (directory_fd < 0)
            return 21;
        unsigned prior = injected;
        armed = kind;
        errno = TEST_ERRNO;
        struct dirent *result = readdir(dir);
        if (armed != none || injected != prior + 1)
            return 22;
        if (result || errno != EIO)
            return 30 + kind;
        if (closedir(dir))
            return 23;
    }
    return 0;
}

static int pipe_failure(void)
{
    int slots[4] = {0x12345678, -100, -200, 0x23456789};
    armed = pipe_no_descriptors;
    errno = TEST_ERRNO;
    int result = pipe(&slots[1]);
    if (armed != none || injected != 1)
        return 50;
    if (result != -1 || errno != EMFILE || slots[0] != 0x12345678 ||
        slots[1] != -100 || slots[2] != -200 || slots[3] != 0x23456789)
        return 51;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 1;
    if (same_text(argv[1], "bad-records")) return bad_records();
    if (same_text(argv[1], "pipe-failure")) return pipe_failure();
    return 2;
}
