#include <asm/unistd.h>
#include <errno.h>
#include <linux/mman.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

enum { REQUEST = 2 * 1024 * 1024 + 137, MAX_MAPPING = REQUEST + 1024 * 1024 };

static struct {
    int armed, deny;
    unsigned failures, mapped, unmapped;
    long address, length;
} witness;

extern long __real___al_syscall(long, long, long, long, long, long, long);

long __wrap___al_syscall(long number, long first, long second, long third,
                         long fourth, long fifth, long sixth)
{
    int selected = witness.armed && number == __NR_mmap &&
                   (unsigned long)second >= REQUEST && (unsigned long)second <= MAX_MAPPING &&
                   (third & (PROT_READ | PROT_WRITE)) == (PROT_READ | PROT_WRITE) &&
                   (fourth & MAP_ANONYMOUS);
    if (selected && witness.deny) {
        ++witness.failures;
        return -ENOMEM;
    }
    long result = __real___al_syscall(number, first, second, third, fourth, fifth, sixth);
    if (selected && (unsigned long)result < (unsigned long)-4095) {
        ++witness.mapped;
        witness.address = result;
        witness.length = second;
    }
    if (witness.armed && number == __NR_munmap && witness.mapped &&
        first == witness.address && second == witness.length && result == 0)
        ++witness.unmapped;
    return result;
}

static int exhaustion(int zeroing)
{
    errno = EDOM;
    witness.deny = witness.armed = 1;
    void *result = zeroing ? calloc(3, REQUEST / 3 + 1) : malloc(REQUEST);
    witness.armed = 0;
    if (result || errno != ENOMEM)
        return 31;
    if (!witness.failures || witness.mapped || witness.unmapped)
        return 32;
    return 0;
}

static int extended_exhaustion(int mode)
{
    int sentinel;
    void *out = &sentinel;
    unsigned char *old = NULL;
    if (mode == 0) {
        old = malloc(53);
        if (!old || (uintptr_t)old % 16)
            return 90;
        for (unsigned i = 0; i < 53; ++i)
            old[i] = (unsigned char)(i * 17 + 3);
    }
    errno = EDOM;
    witness.deny = witness.armed = 1;
    int status;
    if (mode == 0)
        status = realloc(old, REQUEST) != NULL || errno != ENOMEM;
    else if (mode == 1)
        status = aligned_alloc(4096, REQUEST) != NULL || errno != ENOMEM;
    else
        status = posix_memalign(&out, 4096, REQUEST) != ENOMEM || out != &sentinel || errno != EDOM;
    witness.armed = 0;
    if (status)
        return 31;
    if (!witness.failures || witness.mapped || witness.unmapped)
        return 32;
    if (old) {
        for (unsigned i = 0; i < 53; ++i)
            if (old[i] != (unsigned char)(i * 17 + 3))
                return 33;
        free(old);
    }
    return 0;
}

static int direct_release(void)
{
    witness.armed = 1;
    unsigned char *memory = malloc(REQUEST);
    uintptr_t offset = (uintptr_t)memory - (uintptr_t)witness.address;
    if (!memory || (uintptr_t)memory % 16 || witness.mapped != 1 ||
        witness.length < REQUEST || offset > (uintptr_t)witness.length - REQUEST)
        return 90;
    memory[0] = 0x5a;
    memory[REQUEST - 1] = 0xa5;
    errno = EDOM;
    free(memory);
    witness.armed = 0;
    if (witness.unmapped != 1)
        return 31;
    return errno == EDOM ? 0 : 32;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 91;
    if (!strcmp(argv[1], "malloc")) return exhaustion(0);
    if (!strcmp(argv[1], "calloc")) return exhaustion(1);
    if (!strcmp(argv[1], "free")) return direct_release();
    if (!strcmp(argv[1], "realloc")) return extended_exhaustion(0);
    if (!strcmp(argv[1], "aligned_alloc")) return extended_exhaustion(1);
    if (!strcmp(argv[1], "posix_memalign")) return extended_exhaustion(2);
    return 92;
}
