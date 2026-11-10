#include "image.h"

#include <errno.h>
#include <signal.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

struct aux_entry { unsigned long type, value; };
struct linux_iovec { void *address; size_t size; };
extern const struct aux_entry *__al_auxv;
extern void *__al_vdso_clock_entry(void);
extern long __real___al_syscall(long, long, long, long, long, long, long);

enum {
    SYS_CLOCK_GETTIME = 228, SYS_PROCESS_VM_READV = 310, AT_SYSINFO_EHDR = 33,
    OFF = 0, CLOCK_OK, CLOCK_ERROR, RESOLVING_SIGNAL, RESOLVING_FORK,
    SYNTHETIC_SHORT, SYNTHETIC_ERROR, REAL_UNREADABLE,
};
static const time_t stamp = 1738526401;
static volatile sig_atomic_t clocks, copies, reentered, signals;
static volatile unsigned char invoked;
static volatile sig_atomic_t mode;
static int copy_shape;
static unsigned char *image;

static void during_resolution(int signal)
{
    ++signals;
    if (signal != SIGUSR1)
        return;
    int saved = errno;
    errno = ERANGE;
    time_t result = 0;
    reentered = time(&result) == stamp && result == stamp && errno == ERANGE;
    errno = saved;
}

long __wrap___al_syscall(long nr, long a1, long a2, long a3, long a4, long a5, long a6)
{
    if (mode != OFF && nr == SYS_CLOCK_GETTIME) {
        ++clocks;
        if (mode == CLOCK_ERROR)
            return -EOVERFLOW;
        if (a1 != CLOCK_REALTIME || !a2)
            return -EINVAL;
        struct timespec *value = (struct timespec *)a2;
        value->tv_sec = stamp;
        value->tv_nsec = 185000000;
        return 0;
    }

    if (mode != OFF && nr == SYS_PROCESS_VM_READV) {
        ++copies;
        if (mode == RESOLVING_SIGNAL) {
            if (copies == 1 && raise(SIGUSR1))
                return -EIO;
            return -ENOSYS;
        }
        if (mode == RESOLVING_FORK) {
            if (copies == 1) {
                pid_t child = fork();
                if (!child) {
                    errno = ERANGE;
                    _exit(time(NULL) == stamp && errno == ERANGE && copies == 1 ? 0 : 91);
                }
                int status = 0;
                if (child > 0 && waitpid(child, &status, 0) == child && WIFEXITED(status) && !WEXITSTATUS(status))
                    reentered = 1;
            }
            return -ENOSYS;
        }
        if (mode == SYNTHETIC_SHORT || mode == SYNTHETIC_ERROR) {
            const struct linux_iovec *local = (const void *)a2;
            const struct linux_iovec *remote = (const void *)a4;
            if (!local || a3 < 1 || !remote || a5 != 4 || a6)
                return -EINVAL;
            for (long i = 0; i < a5; ++i)
                if (remote[i].address != image + i * PAGE_SIZE || remote[i].size != PAGE_SIZE)
                    return -EINVAL;
            size_t copied = mode == SYNTHETIC_SHORT ? 64 : PAGE_SIZE;
            if (local[0].size < copied)
                return -EINVAL;
            copy_shape = 1;
            memcpy(local[0].address, image, copied);
            return (long)copied;
        }
    }
    return __real___al_syscall(nr, a1, a2, a3, a4, a5, a6);
}

static unsigned long kernel_image(void)
{
    for (size_t i = 0; i < 128 && __al_auxv[i].type; ++i)
        if (__al_auxv[i].type == AT_SYSINFO_EHDR)
            return __al_auxv[i].value;
    return 0;
}

static int native_dispatch(void)
{
    unsigned long base = kernel_image();
    if (!base)
        return 11;
    struct timespec before, after;
    if (clock_gettime(CLOCK_REALTIME, &before))
        return 90;

    mode = CLOCK_ERROR;
    errno = EDOM;
    time_t stored = -1;
    time_t result = time(&stored);
    void *entry = __al_vdso_clock_entry();
    int preserved = errno == EDOM;
    mode = OFF;
    if (clock_gettime(CLOCK_REALTIME, &after))
        return 90;
    uintptr_t callable = (uintptr_t)entry;
    if (copies != 1 || clocks || !preserved || callable <= base || callable - base >= 4 * PAGE_SIZE)
        return 12;
    if (result != stored || result < before.tv_sec || result > after.tv_sec)
        return 13;
    if (clock_gettime(CLOCK_REALTIME, (struct timespec *)(uintptr_t)1) != -1 || errno != EFAULT)
        return 14;
    return 0;
}

static int fallback(int selection, int fake_image)
{
    const struct aux_entry *original = __al_auxv;
    struct aux_entry auxiliary[2] = {{AT_SYSINFO_EHDR, (uintptr_t)image}, {0, 0}};
    if (!image)
        auxiliary[0].type = 0;
    if (selection == RESOLVING_SIGNAL) {
        struct sigaction action = {.sa_handler = during_resolution};
        if (sigemptyset(&action.sa_mask) || sigaction(SIGUSR1, &action, NULL))
            return 90;
    }
    if (fake_image)
        __al_auxv = auxiliary;
    mode = selection;
    errno = EDOM;
    time_t stored = -17;
    time_t result = time(&stored);
    __al_auxv = original;
    void *entry = __al_vdso_clock_entry();
    int preserved = errno;
    mode = OFF;
    if (selection == CLOCK_ERROR)
        return result == (time_t)-1 && stored == -17 && preserved == EOVERFLOW &&
               !entry && clocks == 1 && !copies ? 0 : 21;
    if (result != stamp || stored != stamp || preserved != EDOM || clocks != (selection == RESOLVING_SIGNAL ? 2 : 1))
        return 22;
    if (selection == SYNTHETIC_ERROR) {
        if (!invoked || !copy_shape || entry != image + ENTRY || copies != 1)
            return 23;
    } else if (entry || (fake_image && copies != !!image)) {
        return 24;
    }
    if (selection == SYNTHETIC_SHORT && !copy_shape)
        return 27;
    if (selection == RESOLVING_SIGNAL && (signals != 1 || !reentered))
        return 25;
    if (selection == RESOLVING_FORK && !reentered)
        return 26;
    return 0;
}

static int with_image(int selection)
{
    image = mmap(NULL, 4 * PAGE_SIZE, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (image == MAP_FAILED)
        return 90;
    if (selection == SYNTHETIC_SHORT || selection == SYNTHETIC_ERROR) {
        if (__real___al_syscall(10, (long)image, PAGE_SIZE, PROT_READ | PROT_WRITE, 0, 0, 0))
            return 90;
        /* movabs rax, &invoked; mov byte [rax], 1; mov eax, -EINVAL; ret */
        unsigned char entry[] = {0x48, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0,
                                 0xc6, 0x00, 0x01, 0xb8, 0xea, 0xff, 0xff, 0xff, 0xc3};
        word(entry + 2, (uintptr_t)&invoked, 8);
        fixture_image(image, sizeof entry);
        memcpy(image + ENTRY, entry, sizeof entry);
        if (__real___al_syscall(10, (long)image, PAGE_SIZE, PROT_READ | PROT_EXEC, 0, 0, 0))
            return 90;
    }
    int result = fallback(selection, 1);
    return munmap(image, 4 * PAGE_SIZE) == 0 ? result : 90;
}

static int rejected_auxiliary(const struct aux_entry *replacement)
{
    const struct aux_entry *original = __al_auxv;
    __al_auxv = replacement;
    mode = CLOCK_OK;
    errno = EDOM;
    time_t result = time(NULL);
    __al_auxv = original;
    void *entry = __al_vdso_clock_entry();
    mode = OFF;
    return result == stamp && errno == EDOM && !entry && clocks == 1 && !copies ? 0 : 31;
}

static int bounded_auxiliary(void)
{
    unsigned char *storage = mmap(NULL, 2 * PAGE_SIZE, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (storage == MAP_FAILED ||
        __real___al_syscall(10, (long)storage, PAGE_SIZE, PROT_READ | PROT_WRITE, 0, 0, 0))
        return 90;
    struct aux_entry *entries = (struct aux_entry *)(storage + PAGE_SIZE) - 128;
    for (size_t i = 0; i < 128; ++i)
        entries[i] = (struct aux_entry){1, 0};
    if (__real___al_syscall(10, (long)storage, PAGE_SIZE, PROT_READ, 0, 0, 0))
        return 90;
    int result = rejected_auxiliary(entries);
    return munmap(storage, 2 * PAGE_SIZE) == 0 ? result : 90;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    const char *arg = argv[1];
    if (!strcmp(arg, "auxv-bounds"))
        return bounded_auxiliary();
    if (!strcmp(arg, "unaligned") || !strcmp(arg, "overflow")) {
        unsigned long address = !strcmp(arg, "unaligned") ? PAGE_SIZE + 1ul : UINTPTR_MAX & -PAGE_SIZE;
        const struct aux_entry entries[] = {{AT_SYSINFO_EHDR, address}, {0, 0}};
        return rejected_auxiliary(entries);
    }
    if (!strcmp(arg, "native"))
        return native_dispatch();
    if (!strcmp(arg, "backend"))
        return fallback(CLOCK_OK, 0);
    if (!strcmp(arg, "missing"))
        return fallback(CLOCK_OK, 1);
    if (!strcmp(arg, "raw-error"))
        return fallback(CLOCK_ERROR, 1);
    if (!strcmp(arg, "unreadable"))
        return with_image(REAL_UNREADABLE);
    if (!strcmp(arg, "short"))
        return with_image(SYNTHETIC_SHORT);
    if (!strcmp(arg, "vdso-error"))
        return with_image(SYNTHETIC_ERROR);
    if (!strcmp(arg, "signal"))
        return with_image(RESOLVING_SIGNAL);
    if (!strcmp(arg, "fork"))
        return with_image(RESOLVING_FORK);
    return 91;
}
