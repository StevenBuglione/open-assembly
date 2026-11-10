#define _GNU_SOURCE

#include <setjmp.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#include "test.h"

#define MIN_SAMPLES 2048
#define SEED UINT32_C(0x616c5032)

static const char *mode, *oracle;
static size_t case_index;
#ifndef TEST_LIBFUZZER
static sigjmp_buf guard_return;
static volatile sig_atomic_t guard_armed;
#endif

extern unsigned phase2_abi_probe(uintptr_t function, const uint64_t *arguments);

int phase2_fail(const char *format, ...)
{
    fprintf(stderr, "FAIL %s %s: %s case %zu ", mode, oracle, fixture.name, case_index);
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    fputc('\n', stderr);
    return 1;
}

int phase2_error(const char *format, ...)
{
    fprintf(stderr, "ERROR %s: %s case %zu ", mode, fixture.name, case_index);
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    fputc('\n', stderr);
    return 2;
}

uint32_t phase2_next(uint32_t *state)
{
    uint32_t value = *state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    return *state = value;
}

int phase2_abi(uintptr_t function, const uint64_t arguments[6])
{
    unsigned mask = phase2_abi_probe(function, arguments);
    return mask ? phase2_fail("callee state mask %#x", mask) : 0;
}

int phase2_page_open(struct phase2_page *page)
{
    long size = sysconf(_SC_PAGESIZE);
    if (size < 1024 || (unsigned long)size > SIZE_MAX / 3)
        return phase2_error("invalid page size %ld", size);
    page->size = (size_t)size;
    page->mapping = mmap(NULL, page->size * 3, PROT_NONE,
                         MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (page->mapping == MAP_FAILED)
        return phase2_error("mmap failed");
    page->bytes = page->mapping + page->size;
    return phase2_page_protect(page, 0);
}

int phase2_page_protect(const struct phase2_page *page, int read_only)
{
    if (mprotect(page->bytes, page->size, PROT_READ | (read_only ? 0 : PROT_WRITE)) != 0)
        return phase2_error("mprotect failed");
    return 0;
}

int phase2_page_close(const struct phase2_page *page)
{
    return munmap(page->mapping, page->size * 3) == 0 ? 0 : phase2_error("munmap failed");
}

#ifdef TEST_LIBFUZZER
int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    uint32_t state = SEED;
    case_index = size ? data[0] : 0;
    if (size > 1)
        case_index |= (size_t)data[1] << 8;
    for (size_t i = 2; i < size; ++i)
        state = (state ^ data[i]) * UINT32_C(16777619);
    if (!state)
        state = SEED;
    mode = "fuzz";
    oracle = fixture.unit_oracle;
    if (fixture.sample(case_index, &state, 0))
        abort();
    return 0;
}
#else
static void guard_signal(int signal)
{
    if (guard_armed)
        siglongjmp(guard_return, signal);
    _exit(2);
}

static int run_guard(void)
{
    struct sigaction action = {.sa_handler = guard_signal};
    if (sigemptyset(&action.sa_mask) != 0 || sigaction(SIGSEGV, &action, NULL) != 0
            || sigaction(SIGBUS, &action, NULL) != 0)
        return phase2_error("sigaction failed");
    int signal = sigsetjmp(guard_return, 1);
    if (signal) {
        guard_armed = 0;
        return phase2_fail("access fault (signal %d)", signal);
    }
    guard_armed = 1;
    int status = fixture.guard();
    guard_armed = 0;
    return status;
}

static int sample(size_t minimum, unsigned duration, int compare_host)
{
    struct timespec now;
    time_t deadline = 0;
    if (duration) {
        if (clock_gettime(CLOCK_MONOTONIC, &now) != 0)
            return phase2_error("monotonic clock failed");
        deadline = now.tv_sec + (time_t)duration + 1;
    }
    uint32_t state = SEED;
    for (case_index = 0; case_index < minimum || duration; ++case_index) {
        int status = fixture.sample(case_index, &state, compare_host);
        if (status)
            return status;
        if (case_index + 1 >= minimum && duration && case_index % 64 == 63) {
            if (clock_gettime(CLOCK_MONOTONIC, &now) != 0)
                return phase2_error("monotonic clock failed");
            if (now.tv_sec >= deadline) {
                ++case_index;
                break;
            }
        }
    }
    return 0;
}

int main(int argc, char **argv)
{
    if (argc < 2 || argc > 3) {
        fputs("ERROR usage: checks MODE [SECONDS]\n", stderr);
        return 2;
    }
    mode = argv[1];
    int status;
    if (argc == 2 && strcmp(mode, "abi") == 0) {
        oracle = "abi:sysv-amd64";
        status = fixture.abi();
    } else if (argc == 2 && strcmp(mode, "guard") == 0 && fixture.guard) {
        oracle = fixture.guard_oracle;
        status = run_guard();
    } else if (argc == 2 && strcmp(mode, "unit") == 0) {
        oracle = fixture.unit_oracle;
        status = sample(fixture.directed_cases, 0, 0);
    } else if (strcmp(mode, "differential") == 0 || strcmp(mode, "fuzz") == 0) {
        unsigned duration = 0;
        if (argc == 3) {
            char *end;
            unsigned long input = strtoul(argv[2], &end, 10);
            if (strcmp(mode, "fuzz") != 0 || !argv[2][0] || *end || input > 3600)
                return phase2_error("invalid duration");
            duration = (unsigned)input;
        }
#ifdef TEST_HOST_MUSL
        oracle = "diff:musl";
#else
        oracle = "diff:glibc";
#endif
        if (fixture.differential_oracle)
            oracle = fixture.differential_oracle;
        size_t minimum = fixture.directed_cases > MIN_SAMPLES ? fixture.directed_cases : MIN_SAMPLES;
        status = sample(minimum, duration, 1);
    } else {
        return phase2_error("unrecognized or unavailable mode");
    }
    if (!status) {
        printf("PASS %s %s %s", mode, oracle, fixture.name);
        if (case_index)
            printf(" cases=%zu seed=%#x", case_index, SEED);
        putchar('\n');
    }
    return status;
}
#endif
