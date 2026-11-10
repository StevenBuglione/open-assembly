#define _POSIX_C_SOURCE 200809L
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

enum { THREADS = 4, RECORDS = 384 };

struct job {
    FILE *stream;
    unsigned id;
    const int *start;
};

static void *exercise(void *opaque)
{
    struct job *job = opaque;
    const struct timespec pause = {.tv_nsec = 1000000};
    while (!__atomic_load_n(job->start, __ATOMIC_ACQUIRE))
        (void)nanosleep(&pause, NULL);
    for (unsigned i = 0; i < RECORDS; ++i) {
        size_t size = 1u + (i * 37u + job->id * 13u) % 2048u;
        unsigned char *storage = malloc(size);
        if (!storage)
            return NULL;
        for (size_t j = 0; j < size; ++j)
            storage[j] = (unsigned char)(i + j + job->id);
        unsigned char *resized = realloc(storage, size + 192);
        if (!resized) {
            free(storage);
            return NULL;
        }
        int intact = 1;
        for (size_t j = 0; j < size; ++j) {
            if (resized[j] != (unsigned char)(i + j + job->id))
                intact = 0;
        }
        free(resized);
        uint32_t record = job->id * RECORDS + i;
        if (!intact || fwrite(&record, sizeof record, 1, job->stream) != 1)
            return NULL;
    }
    return job;
}

int main(void)
{
    int start = 0;
    struct job jobs[THREADS];
    pthread_t handles[THREADS];
    FILE *stream = fopen("records", "w+");
    if (!stream)
        return 71;
    for (unsigned i = 0; i < THREADS; ++i) {
        jobs[i] = (struct job){stream, i, &start};
        if (pthread_create(&handles[i], NULL, exercise, &jobs[i]))
            return 72;
    }
    __atomic_store_n(&start, 1, __ATOMIC_RELEASE);
    for (unsigned i = 0; i < THREADS; ++i) {
        void *result = NULL;
        if (pthread_join(handles[i], &result) || result != &jobs[i])
            return 73;
    }
    if (fseek(stream, 0, SEEK_SET))
        return 74;
    unsigned char seen[THREADS * RECORDS] = {0};
    for (unsigned i = 0; i < THREADS * RECORDS; ++i) {
        uint32_t record;
        if (fread(&record, sizeof record, 1, stream) != 1 || record >= THREADS * RECORDS || seen[record])
            return 75;
        seen[record] = 1;
    }
    if (fgetc(stream) != EOF || ferror(stream) || !feof(stream) || fclose(stream))
        return 76;
    return 0;
}
