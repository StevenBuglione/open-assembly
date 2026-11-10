#include <errno.h>
#include <locale.h>
#include <pthread.h>
#include <string.h>
#include <time.h>
#include <uchar.h>
#include <wchar.h>

enum { WORKERS = 2, ROUNDS = 16 };

struct job {
    const char *utf8;
    wchar_t scalar;
    char16_t high, low;
    pthread_cond_t ready;
    int waiting, released, result, destructed;
};

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_key_t key;

static void destroy_value(void *value)
{
    struct job *job = value;
    ++job->destructed;
}

static int prepare(struct job *job)
{
    wchar_t wide = 0x55;
    char16_t unit = 0;
    char encoded[5] = {'#', '#', '#', '#', '#'};
    if (mbrtowc(&wide, job->utf8, 2, NULL) != (size_t)-2 || wide != 0x55)
        return 11;
    if (mbrtoc16(&unit, job->utf8, 4, NULL) != 4 || unit != job->high ||
        c16rtomb(encoded, job->high, NULL) || encoded[0] != '#')
        return 12;
    if (pthread_getspecific(key) || pthread_setspecific(key, job) ||
        pthread_getspecific(key) != job)
        return 13;
    return 0;
}

static int complete(struct job *job)
{
    wchar_t wide = 0;
    char16_t unit = 0;
    char encoded[5] = {'#', '#', '#', '#', '#'};
    if (pthread_getspecific(key) != job || pthread_setspecific(key, NULL) ||
        pthread_getspecific(key) || pthread_setspecific(key, job))
        return 21;
    if (mbrtowc(&wide, job->utf8 + 2, 2, NULL) != 2 || wide != job->scalar)
        return 22;
    if (mbrtoc16(&unit, "", 0, NULL) != (size_t)-3 || unit != job->low ||
        mbrtoc16(&unit, "B", 1, NULL) != 1 || unit != 'B' ||
        c16rtomb(encoded, job->low, NULL) != 4 || memcmp(encoded, job->utf8, 4) ||
        encoded[4] != '#')
        return 23;
    return 0;
}

static void *run(void *value)
{
    struct job *job = value;
    errno = EDOM;
    int result = prepare(job);
    if (pthread_mutex_lock(&lock))
        return NULL;
    job->waiting = 1;
    unsigned attempts = 0;
    while (!job->released && attempts++ < 10000) {
        if (pthread_cond_wait(&job->ready, &lock))
            break;
    }
    int released = job->released;
    if (pthread_mutex_unlock(&lock) || !released || errno != EDOM)
        return NULL;
    if (!result)
        result = complete(job);
    job->result = errno == EDOM ? result : 24;
    return job;
}

static int notify(struct job *jobs)
{
    const struct timespec pause = {.tv_nsec = 1000000};
    for (unsigned tries = 0; tries < 2000; ++tries) {
        if (pthread_mutex_lock(&lock))
            return 0;
        if (jobs[0].waiting && jobs[1].waiting) {
            int good = 1;
            for (int i = 0; i < WORKERS; ++i) {
                jobs[i].released = 1;
                if (pthread_cond_signal(&jobs[i].ready))
                    good = 0;
            }
            return !pthread_mutex_unlock(&lock) && good;
        }
        if (pthread_mutex_unlock(&lock))
            return 0;
        (void)nanosleep(&pause, NULL);
    }
    return 0;
}

int main(void)
{
    if (!setlocale(LC_CTYPE, "C.UTF-8") || pthread_key_create(&key, destroy_value))
        return 30;
    int own_value;
    if (pthread_setspecific(key, &own_value))
        return 31;
    for (unsigned round = 0; round < ROUNDS; ++round) {
        struct job jobs[WORKERS] = {
            {.utf8 = "\xf0\x9f\x99\x82", .scalar = 0x1f642, .high = 0xd83d, .low = 0xde42},
            {.utf8 = "\xf4\x8f\xbf\xbf", .scalar = 0x10ffff, .high = 0xdbff, .low = 0xdfff},
        };
        pthread_t handles[WORKERS];
        for (int i = 0; i < WORKERS; ++i) {
            if (pthread_cond_init(&jobs[i].ready, NULL) ||
                pthread_create(&handles[i], NULL, run, &jobs[i]))
                return 32;
        }
        if (!notify(jobs) || pthread_getspecific(key) != &own_value)
            return 33;
        for (int i = 0; i < WORKERS; ++i) {
            void *result = NULL;
            if (pthread_join(handles[i], &result) || result != &jobs[i])
                return 34;
            if (jobs[i].result)
                return jobs[i].result;
            if (jobs[i].destructed != 1 || pthread_cond_destroy(&jobs[i].ready))
                return 35;
        }
    }
    return pthread_key_delete(key) || pthread_mutex_destroy(&lock) ? 36 : 0;
}
