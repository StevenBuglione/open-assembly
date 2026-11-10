#define _POSIX_C_SOURCE 200809L
#include "support.h"

static int ready, release, finished;

#ifndef OA_PHASE8_HOST
extern long __al_syscall(long, long, long, long, long, long, long);
enum { SYS_MINCORE = 27 };
struct aux_entry { unsigned long type, value; };
extern const struct aux_entry *const __al_auxv;
static unsigned long ranges[4];

static size_t page_size(void)
{
    for (const struct aux_entry *item = __al_auxv; item->type; ++item) {
        if (item->type == 6)  /* AT_PAGESZ */
            return item->value;
    }
    return 0;
}
#endif

static int body(void *unused)
{
    (void)unused;
#ifndef OA_PHASE8_HOST
    unsigned long thread_base;
    __asm__ volatile("movq %%fs:0,%0" : "=r"(thread_base));
    /* The published TCB layout describes the TLS and worker stack mappings. */
    memcpy(ranges, (const void *)(thread_base + 0x50), sizeof ranges);
#endif
    mark(&ready);
    if (!wait_for(&release))
        return 91;
    mark(&finished);
    return -1;
}

#ifndef OA_PHASE8_HOST
static int unmapped(void)
{
    const struct timespec pause = {.tv_nsec = 1000000};
    for (int tries = 0; tries < 1000; ++tries) {
        unsigned char bits;
        if (__al_syscall(SYS_MINCORE, ranges[0], 1, (long)&bits, 0, 0, 0) == -ENOMEM &&
            __al_syscall(SYS_MINCORE, ranges[2], 1, (long)&bits, 0, 0, 0) == -ENOMEM)
            return 1;
        (void)nanosleep(&pause, NULL);
    }
    return 0;
}
#endif

int main(void)
{
    thrd_t worker;
    errno = EDOM;
    if (!success(thrd_create(&worker, body, NULL)) || !wait_for(&ready))
        return 10;
#ifndef OA_PHASE8_HOST
    size_t page = page_size();
    unsigned char bits;
    if (!page || !ranges[0] || ranges[1] < 128 || !ranges[2] || ranges[3] <= page ||
        ranges[0] % page || ranges[2] % page || ranges[3] % page ||
        __al_syscall(SYS_MINCORE, ranges[0], 1, (long)&bits, 0, 0, 0) ||
        __al_syscall(SYS_MINCORE, ranges[2], 1, (long)&bits, 0, 0, 0))
        return 13;
#endif
    errno = EDOM;
    if (!success(thrd_detach(worker)))
        return 11;
    mark(&release);
    if (!wait_for(&finished))
        return 12;
#ifndef OA_PHASE8_HOST
    if (!unmapped())
        return 14;
    for (size_t i = 0; i < 4; i += 2) {
        for (unsigned long offset = 0; offset < ranges[i + 1]; offset += page) {
            unsigned char bits;
            if (__al_syscall(SYS_MINCORE, ranges[i] + offset, 1, (long)&bits, 0, 0, 0) != -ENOMEM)
                return 15;
        }
    }
#endif
    return 0;
}
