#include <errno.h>
#include <locale.h>
#include <pthread.h>
#include <string.h>
#include <time.h>
#include <uchar.h>
#include <wchar.h>

enum { WORKERS = 2, ROUNDS = 16 };

struct sequence {
    const char *bytes;
    wchar_t scalar;
    char16_t high, low;
};

static const struct sequence input[] = {
    {"\xf0\x90\x80\x80", 0x10000, 0xd800, 0xdc00},
    {"\xf0\x9f\x99\x82", 0x1f642, 0xd83d, 0xde42},
    {"\xf4\x8f\xbf\xbf", 0x10ffff, 0xdbff, 0xdfff},
};

struct job { int index, ready, release, result; };
static struct job jobs[WORKERS];

static int await(const int *flag)
{
    const struct timespec pause = {.tv_nsec = 1000000};
    int saved = errno;
    int ready = 0;
    for (unsigned i = 0; i < 2000; ++i) {
        if (__atomic_load_n(flag, __ATOMIC_ACQUIRE)) {
            ready = 1;
            break;
        }
        (void)nanosleep(&pause, NULL);
    }
    errno = saved;
    return ready;
}

static void release(int *flag)
{
    __atomic_store_n(flag, 1, __ATOMIC_RELEASE);
}

static int prepare(int index)
{
    const struct sequence *item = &input[index];
    wchar_t wide = 0x55;
    char32_t scalar = 0x55;
    char16_t unit = 0;
    char output[5] = {'#', '#', '#', '#', '#'};
    errno = 401 + index;
    if (mbrlen(item->bytes, 2, NULL) != (size_t)-2 ||
        mbrtowc(&wide, item->bytes, 1, NULL) != (size_t)-2 || wide != 0x55 ||
        mbrtoc32(&scalar, item->bytes, 3, NULL) != (size_t)-2 || scalar != 0x55)
        return 1;
    if (mbrtoc16(&unit, item->bytes, 4, NULL) != 4 || unit != item->high ||
        c16rtomb(output, item->high, NULL) != 0 || output[0] != '#' || errno != 401 + index)
        return 2;
    return 0;
}

static int complete(int index)
{
    const struct sequence *item = &input[index];
    wchar_t wide = 0;
    char32_t scalar = 0;
    char16_t unit = 0;
    char output[5] = {'#', '#', '#', '#', '#'};
    if (mbrlen(item->bytes + 2, 2, NULL) != 2 ||
        mbrtowc(&wide, item->bytes + 1, 3, NULL) != 3 || wide != item->scalar ||
        mbrtoc32(&scalar, item->bytes + 3, 1, NULL) != 1 || scalar != (char32_t)item->scalar)
        return 3;
    if (mbrtoc16(&unit, "X", 0, NULL) != (size_t)-3 || unit != item->low ||
        mbrtoc16(&unit, "X", 1, NULL) != 1 || unit != 'X' ||
        c16rtomb(output, item->low, NULL) != 4 ||
        memcmp(output, item->bytes, 4) || output[4] != '#' || errno != 401 + index)
        return 4;
    return 0;
}

static void *worker(void *opaque)
{
    struct job *job = opaque;
    int index = job->index;
    int result = prepare(index);
    if (!result && index == 2) {
        wchar_t untouched = 0x44;
        if (mbrtowc(&untouched, "!", 1, NULL) != (size_t)-1 || untouched != 0x44 || errno != EILSEQ)
            result = 5;
        errno = 401 + index;
        if (!result && mbrtowc(&untouched, input[index].bytes, 1, NULL) != (size_t)-2)
            result = 6;
    }
    release(&job->ready);
    if (!await(&job->release))
        result = 7;
    if (!result)
        result = complete(index);
    /* Leave a pending state behind to distinguish a freshly created
       thread from a stale state copied out of an earlier descriptor. */
    if (!result && mbrlen("\xe2", 1, NULL) != (size_t)-2)
        result = 8;
    job->result = result;
    return job;
}

int main(void)
{
    if (!setlocale(LC_CTYPE, "C.UTF-8"))
        return 10;
    for (unsigned round = 0; round < ROUNDS; ++round) {
        int status = prepare(0);
        if (status)
            return 10 + status;
        pthread_t handles[WORKERS];
        for (int i = 0; i < WORKERS; ++i) {
            jobs[i] = (struct job){.index = i + 1};
            if (pthread_create(&handles[i], NULL, worker, &jobs[i]) || errno != 401)
                return 13;
        }
        for (int i = 0; i < WORKERS; ++i) {
            if (!await(&jobs[i].ready))
                return 14;
        }
        status = complete(0);
        if (status)
            return 20 + status;
        for (int i = 0; i < WORKERS; ++i)
            release(&jobs[i].release);
        for (int i = 0; i < WORKERS; ++i) {
            void *value = NULL;
            if (pthread_join(handles[i], &value) || value != &jobs[i] || errno != 401)
                return 25;
            if (jobs[i].result)
                return 30 + jobs[i].result;
        }
    }
    return 0;
}
