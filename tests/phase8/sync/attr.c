#define _GNU_SOURCE
#include "sync.h"
#include <limits.h>
#include <stdint.h>

#ifndef OA_PHASE8_HOST
struct aux_entry { unsigned long type, value; };
extern const struct aux_entry *const __al_auxv;

static size_t page_size(void)
{
    for (const struct aux_entry *item = __al_auxv; item->type; ++item) {
        if (item->type == 6)  /* AT_PAGESZ */
            return item->value;
    }
    return 0;
}
#endif

static int visited;
static int job_token;

static void *identify(void *argument)
{
    mark(&visited);
    return argument;
}

static void *large_stack(void *argument)
{
    /* Touch each page of a stack whose requested size exceeds the default. */
    volatile unsigned char local[1024 * 1024 + 32768];
    for (size_t i = 0; i < sizeof local; i += 4096)
        local[i] = (unsigned char)(i / 4096);
    for (size_t i = 0; i < sizeof local; i += 4096) {
        if (local[i] != (unsigned char)(i / 4096))
            return NULL;
    }
    return argument;
}

int main(int argc, char **argv)
{
    pthread_attr_t attr;
    /* A zero-return initializer must not pass by inheriting a zeroed object. */
    memset(&attr, 0xa5, sizeof attr);
    int detach = -99;
    size_t count = 0;
    errno = EDOM;
    if (!passed(pthread_attr_init(&attr)))
        return 10;
    if (selection(argc, argv, "init")) {
        if (!passed(pthread_attr_getdetachstate(&attr, &detach)) ||
            detach != PTHREAD_CREATE_JOINABLE)
            return 11;
#ifndef OA_PHASE8_HOST
        size_t page = page_size();
        if (!page || !passed(pthread_attr_getguardsize(&attr, &count)) || count != page ||
            !passed(pthread_attr_getstacksize(&attr, &count)) || count != 1024 * 1024)
            return 12;
#endif
    } else if (selection(argc, argv, "get-detach")) {
        if (!passed(pthread_attr_getdetachstate(&attr, &detach)) ||
            detach != PTHREAD_CREATE_JOINABLE)
            return 13;
    } else if (selection(argc, argv, "get-guard")) {
        count = (size_t)-1;
        if (!passed(pthread_attr_setguardsize(&attr, 0)))
            return 14;
        if (!passed(pthread_attr_getguardsize(&attr, &count)) || count != 0)
            return 15;
    } else if (selection(argc, argv, "get-stack")) {
        count = 1;
        if (!passed(pthread_attr_getstacksize(&attr, &count)) || count < (size_t)PTHREAD_STACK_MIN)
            return 16;
    } else if (selection(argc, argv, "set-detach")) {
        if (!passed(pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED)) ||
            !correct(pthread_attr_setdetachstate(&attr, INT_MAX), EINVAL) ||
            !passed(pthread_attr_getdetachstate(&attr, &detach)) ||
            detach != PTHREAD_CREATE_DETACHED)
            return 17;
        pthread_t worker;
        if (!passed(pthread_create(&worker, &attr, identify, &job_token)) || waiting(&visited))
            return 18;
    } else if (selection(argc, argv, "set-guard")) {
        const size_t requested = 12345;
        if (!passed(pthread_attr_setguardsize(&attr, requested)) ||
            !passed(pthread_attr_getguardsize(&attr, &count)) || count != requested)
            return 19;
        if (!passed(pthread_attr_setguardsize(&attr, 0)) ||
            !passed(pthread_attr_getguardsize(&attr, &count)) || count != 0)
            return 20;
    } else if (selection(argc, argv, "set-stack")) {
        const size_t requested = 2 * 1024 * 1024;
        if (!passed(pthread_attr_setstacksize(&attr, requested)) ||
            !correct(pthread_attr_setstacksize(&attr, PTHREAD_STACK_MIN - 1), EINVAL) ||
            !passed(pthread_attr_getstacksize(&attr, &count)) || count != requested)
            return 21;
        pthread_t worker;
        void *result = NULL;
        if (!passed(pthread_create(&worker, &attr, large_stack, &job_token)) ||
            !passed(pthread_join(worker, &result)) || result != &job_token)
            return 22;
    } else if (selection(argc, argv, "destroy")) {
        if (!passed(pthread_attr_destroy(&attr)))
            return 23;
        return correct(pthread_attr_destroy(&attr), EINVAL) ? 0 : 24;
    } else {
        return 90;
    }
    return passed(pthread_attr_destroy(&attr)) ? 0 : 25;
}
