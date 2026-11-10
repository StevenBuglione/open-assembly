#ifndef AL_PHASE2_TEST_H
#define AL_PHASE2_TEST_H

#include <stddef.h>
#include <stdint.h>

#define JOIN_IMPL(a, b) a##b
#define JOIN(a, b) JOIN_IMPL(a, b)
#define STR_IMPL(x) #x
#define STR(x) STR_IMPL(x)

#define CANDIDATE JOIN(__al_test_, TEST_NAME)
#define ABI_CALL(...) phase2_abi((uintptr_t)CANDIDATE, (const uint64_t[6]){__VA_ARGS__})
#define ADDRESS(pointer) ((uintptr_t)(pointer))

struct phase2_fixture {
    const char *name;
    const char *unit_oracle;
    const char *guard_oracle;
    const char *differential_oracle;
    size_t directed_cases;
    int (*abi)(void);
    int (*guard)(void);
    int (*sample)(size_t index, uint32_t *state, int compare_host);
};

extern const struct phase2_fixture fixture;

struct phase2_page {
    unsigned char *mapping;
    unsigned char *bytes;
    size_t size;
};

int phase2_fail(const char *format, ...) __attribute__((format(printf, 1, 2)));
int phase2_error(const char *format, ...) __attribute__((format(printf, 1, 2)));
int phase2_abi(uintptr_t function, const uint64_t arguments[6]);
int phase2_page_open(struct phase2_page *page);
int phase2_page_protect(const struct phase2_page *page, int read_only);
int phase2_page_close(const struct phase2_page *page);
uint32_t phase2_next(uint32_t *state);

static inline int sign_of(int value)
{
    return (value > 0) - (value < 0);
}

static inline int equal_bytes(const void *left, const void *right, size_t size)
{
    const unsigned char *a = left, *b = right;
    for (size_t i = 0; i < size; ++i)
        if (a[i] != b[i])
            return 0;
    return 1;
}

static inline unsigned char *edge(const struct phase2_page *page, size_t extent, int high)
{
    return page->bytes + (high ? page->size - extent : 0);
}

#endif
