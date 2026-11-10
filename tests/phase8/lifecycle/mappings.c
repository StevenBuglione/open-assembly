#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "mapping_observer.h"

extern long __al_syscall(long, long, long, long, long, long, long);

enum { SYS_WRITE = 1, SYS_MINCORE = 27 };

struct mappings {
    int ready, release;
    uintptr_t tls, stack, tcb, stack_sample;
    size_t tls_length, stack_length;
};

static void pause_once(void)
{
    const struct timespec pause = {.tv_nsec = 1000000};
    int saved = errno;
    (void)nanosleep(&pause, NULL);
    errno = saved;
}

static void *measure(void *opaque)
{
    struct mappings *item = opaque;
    __asm__ volatile("movq %%fs:0x50, %0; movq %%fs:0x58, %1;"
                     "movq %%fs:0x60, %2; movq %%fs:0x68, %3; movq %%fs:0, %4"
                     : "=r"(item->tls), "=r"(item->tls_length), "=r"(item->stack),
                       "=r"(item->stack_length), "=r"(item->tcb));
    item->stack_sample = (uintptr_t)&item;
    __atomic_store_n(&item->ready, 1, __ATOMIC_RELEASE);
    for (int retries = 0; retries < 2000; ++retries) {
        if (__atomic_load_n(&item->release, __ATOMIC_ACQUIRE))
            return opaque;
        pause_once();
    }
    return NULL;
}

static long mapping_status(uintptr_t page, unsigned long size)
{
    unsigned char presence;
    return __al_syscall(SYS_MINCORE, (long)page, (long)size, (long)&presence, 0, 0, 0);
}

static int wait_unmapped(const struct mappings *item, unsigned long page)
{
    for (int retries = 0; retries < 1000; ++retries) {
        if (mapping_status(item->tls, page) == -ENOMEM &&
            mapping_status(item->tls + (item->tls_length - 1) / page * page, page) == -ENOMEM &&
            mapping_status(item->stack, page) == -ENOMEM &&
            mapping_status(item->stack + item->stack_length - page, page) == -ENOMEM)
            return 1;
        pause_once();
    }
    return 0;
}

static int unmapped(uintptr_t base, size_t length, unsigned long page)
{
    for (size_t offset = 0; offset < length; offset += page) {
        if (mapping_status(base + offset, page) != -ENOMEM)
            return 0;
    }
    return 1;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    unsigned long page = startup_page_size();
    struct mappings item = {0};
    pthread_t handle;
    if (!page || pthread_create(&handle, NULL, measure, &item))
        return 60;
    for (int retries = 0; retries < 2000 && !__atomic_load_n(&item.ready, __ATOMIC_ACQUIRE);
         ++retries)
        pause_once();
    if (!__atomic_load_n(&item.ready, __ATOMIC_ACQUIRE))
        return 61;
    if (item.tls % page || item.stack % page || item.tls_length < 128 ||
        item.stack_length != page + 1024 * 1024 || item.tcb < item.tls ||
        item.tcb - item.tls > item.tls_length - 128 ||
        item.stack_sample < item.stack + page ||
        item.stack_sample - item.stack >= item.stack_length ||
        (item.tls < item.stack + item.stack_length &&
         item.stack <= item.tls + (item.tls_length - 1) / page * page) ||
        mapping_status(item.tls, page) || mapping_status(item.stack, page))
        return 62;

    errno = EDOM;
    if (strcmp(argv[1], "detach-live") == 0) {
        if (pthread_detach(handle) || errno != EDOM)
            return 64;
        __atomic_store_n(&item.release, 1, __ATOMIC_RELEASE);
    } else if (strcmp(argv[1], "detach-exited") == 0) {
        const int *tid = (const int *)(item.tcb + 0x70);
        __atomic_store_n(&item.release, 1, __ATOMIC_RELEASE);
        for (int retries = 0; retries < 2000 && __atomic_load_n(tid, __ATOMIC_ACQUIRE); ++retries)
            pause_once();
        if (__atomic_load_n(tid, __ATOMIC_ACQUIRE))
            return 65;
        if (pthread_detach(handle) || errno != EDOM)
            return 66;
    } else if (strcmp(argv[1], "guard") == 0) {
        int fds[2];
        if (pipe(fds))
            return 67;
        long bottom = __al_syscall(SYS_WRITE, fds[1], (long)item.stack, 1, 0, 0, 0);
        long above = __al_syscall(SYS_WRITE, fds[1], (long)(item.stack + page), 1, 0, 0, 0);
        if (close(fds[0]) || close(fds[1]) || bottom != -EFAULT || above != 1)
            return 68;
        __atomic_store_n(&item.release, 1, __ATOMIC_RELEASE);
        if (pthread_join(handle, NULL) || errno != EDOM)
            return 69;
    } else {
        return 91;
    }
    return wait_unmapped(&item, page) && unmapped(item.tls, item.tls_length, page) &&
           unmapped(item.stack, item.stack_length, page) ? 0 : 63;
}
