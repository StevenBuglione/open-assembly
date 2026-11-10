#define _POSIX_C_SOURCE 200809L
#include "sync.h"

static pthread_key_t key;
static int main_value;
static int worker_value;
static int calls;
static int invalid;
static int rearm_limit;

static void destructor(void *pointer)
{
    if (pointer != &worker_value || pthread_getspecific(key) != NULL || errno != EDOM)
        invalid = 1;
    ++calls;
    pthread_key_t nested;
    if (!passed(pthread_key_create(&nested, NULL)) ||
        !passed(pthread_setspecific(nested, &worker_value)) ||
        pthread_getspecific(nested) != &worker_value || !passed(pthread_key_delete(nested)))
        invalid = 1;
    if (calls < rearm_limit && !passed(pthread_setspecific(key, pointer)))
        invalid = 1;
}

static void *specific_body(void *argument)
{
    errno = EDOM;
    if (pthread_getspecific(key) != NULL ||
        !passed(pthread_setspecific(key, &worker_value)) ||
        pthread_getspecific(key) != &worker_value || !passed(0))
        return NULL;
    return argument;
}

static int exit_callbacks(int cap)
{
    rearm_limit = cap ? 9 : 4;
    if (!passed(pthread_key_create(&key, destructor)) ||
        !passed(pthread_setspecific(key, &main_value)))
        return 20;
    pthread_t thread;
    void *result = NULL;
    if (!passed(pthread_create(&thread, NULL, specific_body, &worker_value)) ||
        !passed(pthread_join(thread, &result)) || result != &worker_value)
        return 21;
    if (calls != 4 || invalid || pthread_getspecific(key) != &main_value || !passed(0))
        return 22;
    if (!passed(pthread_key_delete(key)) || calls != 4)
        return 23;
    return 0;
}

static int capacity(void)
{
    pthread_key_t all[128];
    for (size_t i = 0; i < sizeof all / sizeof all[0]; ++i) {
        if (!passed(pthread_key_create(&all[i], destructor)) ||
            !passed(pthread_setspecific(all[i], &worker_value)))
            return 30;
        for (size_t j = 0; j < i; ++j) {
            if (all[i] == all[j])
                return 31;
        }
    }
    pthread_key_t extra = (pthread_key_t)-1;
    if (!correct(pthread_key_create(&extra, NULL), EAGAIN) || extra != (pthread_key_t)-1)
        return 32;
    pthread_key_t dead = all[63];
    if (!passed(pthread_key_delete(dead)) || calls || pthread_getspecific(dead) != NULL ||
        !correct(pthread_setspecific(dead, &main_value), EINVAL))
        return 33;
    if (!passed(pthread_key_create(&all[63], NULL)) || pthread_getspecific(all[63]) != NULL)
        return 34;
    for (size_t i = 0; i < sizeof all / sizeof all[0]; ++i) {
        if ((i != 63 && pthread_getspecific(all[i]) != &worker_value) ||
            !passed(pthread_key_delete(all[i])))
            return 35;
    }
    return calls || !passed(0) ? 36 : 0;
}

static int direct(int deleted)
{
    pthread_key_t direct_key = (pthread_key_t)-1;
    if (!passed(pthread_key_create(&direct_key, NULL)) || direct_key == (pthread_key_t)-1)
        return 11;
    if (pthread_getspecific(direct_key) || !passed(0))
        return 12;
    if (!passed(pthread_setspecific(direct_key, &main_value)) ||
        pthread_getspecific(direct_key) != &main_value || !passed(0))
        return 13;
    if (!passed(pthread_key_delete(direct_key)))
        return 14;
    if (deleted && (pthread_getspecific(direct_key) != NULL ||
                    !correct(pthread_key_delete(direct_key), EINVAL)))
        return 15;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    errno = EDOM;
    if (!strcmp(argv[1], "capacity"))
        return capacity();
    if (!strcmp(argv[1], "exit") || !strcmp(argv[1], "exit-cap"))
        return exit_callbacks(!strcmp(argv[1], "exit-cap"));
    return direct(!strcmp(argv[1], "delete"));
}
