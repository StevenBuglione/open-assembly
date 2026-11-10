#define _GNU_SOURCE
#include <errno.h>
#include <locale.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/wait.h>
#include <uchar.h>
#include <unistd.h>
#include <wchar.h>

static int ready[2], release[2];
static pthread_mutex_t application_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_once_t once = PTHREAD_ONCE_INIT;
static pthread_key_t key;
static _Thread_local uint64_t initialized = UINT64_C(0x890b744a11337cc5);
static _Thread_local uint64_t zero;
static _Thread_local int outcome;
static const uint64_t worker_value = UINT64_C(0x73ea49602c17af6d);

#ifdef OA_PHASE8_HOST
#include <sys/syscall.h>
static long tid(void) { return syscall(SYS_gettid); }
#else
extern long __al_syscall(long, long, long, long, long, long, long);
static long tid(void) { return __al_syscall(186, 0, 0, 0, 0, 0, 0); }

static uintptr_t fs_word(uintptr_t offset)
{
    uintptr_t result;
    __asm__ volatile ("movq %%fs:(%1), %0" : "=r"(result) : "r"(offset));
    return result;
}

static uint32_t fs_dword(uintptr_t offset)
{
    uint32_t result;
    __asm__ volatile ("movl %%fs:(%1), %0" : "=r"(result) : "r"(offset));
    return result;
}
#endif

static void *peer(void *unused)
{
    (void)unused;
    if (pthread_mutex_lock(&application_lock))
        return (void *)(uintptr_t)1;
    flockfile(stdout);
    char command;
    int failed = write(ready[1], "r", 1) != 1 || read(release[0], &command, 1) != 1 || command != 'q';
    funlockfile(stdout);
    return (void *)(uintptr_t)(pthread_mutex_unlock(&application_lock) || failed);
}

static void child_from_worker(void)
{
    const pid_t origin = getpid();
    long worker_tid = tid();
    uintptr_t value_address = (uintptr_t)&initialized, errno_address = (uintptr_t)&errno;
    if (worker_tid <= 0 || worker_tid == origin) {
        outcome = 11;
        return;
    }
#ifndef OA_PHASE8_HOST
    static const uintptr_t preserved[] = {0x00, 0x28, 0x30, 0x48, 0x50, 0x58, 0x60, 0x68, 0x910, 0x918};
    uintptr_t descriptor[sizeof preserved / sizeof *preserved];
    uintptr_t multibyte[16];
    for (size_t i = 0; i < sizeof preserved / sizeof *preserved; ++i)
        descriptor[i] = fs_word(preserved[i]);
    for (size_t i = 0; i < sizeof multibyte / sizeof *multibyte; ++i)
        multibyte[i] = fs_word(0x80 + i * sizeof(uintptr_t));
    if (!descriptor[0] || !descriptor[3] || !descriptor[8] || fs_dword(0x70) != (uint32_t)worker_tid) {
        outcome = 12;
        return;
    }
#endif

    errno = 967;
    pid_t child = fork();
    int error = errno;
    if (!child) {
        if (getpid() == origin)
            _exit(21);
        if (tid() != getpid() || (uintptr_t)&initialized != value_address || initialized != worker_value ||
            zero != worker_value + 1 || (uintptr_t)&errno != errno_address || error != 967)
            _exit(22);
#ifndef OA_PHASE8_HOST
        for (size_t i = 0; i < sizeof preserved / sizeof *preserved; ++i)
            if (fs_word(preserved[i]) != descriptor[i])
                _exit(23);
        for (size_t i = 0; i < sizeof multibyte / sizeof *multibyte; ++i)
            if (fs_word(0x80 + i * sizeof(uintptr_t)) != multibyte[i])
                _exit(24);
        if (fs_dword(0x70) != (uint32_t)tid() || fs_dword(0x74) || fs_word(0x78) ||
            fs_word(0x100) || fs_dword(0x108))
            _exit(25);
        unsigned retained = 0;
        for (size_t i = 0; i < 128; ++i)
            retained += fs_word(0x118 + i * 16) == value_address;
        if (retained != 1)
            _exit(26);
#endif
        _exit(0);
    }
    int status;
    if (child < 0 || error != 967 || tid() != worker_tid ||
        waitpid(child, &status, 0) != child || !WIFEXITED(status)) {
        outcome = 13;
        return;
    }
    if (WEXITSTATUS(status)) {
        outcome = WEXITSTATUS(status);
        return;
    }
    if (pthread_getspecific(key) != &initialized)
        outcome = 14;
}

static void *forker(void *unused)
{
    (void)unused;
    if (initialized != UINT64_C(0x890b744a11337cc5) || zero)
        return (void *)(uintptr_t)15;
    initialized = worker_value;
    zero = worker_value + 1;
    if (pthread_setspecific(key, &initialized))
        return (void *)(uintptr_t)16;
    char16_t first;
    if (mbrtowc(NULL, "\xe2", 1, NULL) != (size_t)-2 ||
        mbrtoc16(&first, "\xf0\x90\x80\x80", 4, NULL) != 4 || first != 0xd800)
        return (void *)(uintptr_t)17;
    if (pthread_once(&once, child_from_worker))
        return (void *)(uintptr_t)18;
    return (void *)(uintptr_t)outcome;
}

int main(void)
{
    if (!setlocale(LC_CTYPE, "C.UTF-8") || pipe(ready) || pipe(release) || pthread_key_create(&key, NULL))
        return 90;
    pthread_t other, invoking;
    if (pthread_create(&other, NULL, peer, NULL))
        return 91;
    char state;
    if (read(ready[0], &state, 1) != 1 || state != 'r' ||
        pthread_create(&invoking, NULL, forker, NULL))
        return 92;
    void *result;
    if (pthread_join(invoking, &result))
        return 93;
    int status = (int)(uintptr_t)result;
    if (!status && pthread_mutex_trylock(&application_lock) != EBUSY)
        status = 19;
    if (write(release[1], "q", 1) != 1 || pthread_join(other, &result) || result)
        return 94;
    if (close(ready[0]) || close(ready[1]) || close(release[0]) || close(release[1]) ||
        pthread_key_delete(key) || pthread_mutex_destroy(&application_lock))
        return 95;
    return status;
}
