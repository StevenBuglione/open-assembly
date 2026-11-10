#include "contract.h"

#ifdef OA_STAT_QUERY_RAW
static int route(int selector, long descriptor, const char *path, long flags,
                 struct stat *output)
{
    struct kernel_stat raw;
    long result = selector == QUERY_FSTAT ? raw_fstat((int)descriptor, &raw) :
                  raw_stat((int)descriptor, path, (int)flags, &raw);
    if (result) {
        errno = (int)-result;
        return -1;
    }
    unsigned char *target = (unsigned char *)output;
    const unsigned char *source = (const unsigned char *)&raw;
    set_bytes(target, sizeof *output, 0);
    for (size_t i = 0; i < 36; ++i)
        target[i] = source[i];
    for (size_t i = 40; i < 120; ++i)
        target[i] = source[i];
    return 0;
}
#else
static int route(int selector, long descriptor, const char *path, long flags,
                 struct stat *output)
{
    long result = __al_stat_query(selector, descriptor, path, flags, output);
    if (result != 0 && result != -1)
        _exit(21);
    return (int)result;
}
#endif

#define stat(path, output) route(QUERY_FSTATAT, AT_FDCWD, path, 0, output)
#define lstat(path, output) route(QUERY_FSTATAT, AT_FDCWD, path, AT_SYMLINK_NOFOLLOW, output)
#define fstat(fd, output) route(QUERY_FSTAT, fd, NULL, 0, output)
#define fstatat(fd, path, output, flags) route(QUERY_FSTATAT, fd, path, flags, output)

/* Reuse the unchanged independent record generator and Linux attribute model. */
#include "../stat_identity/packets.c"
