#include <arena.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>

#define MAX UINT64_MAX
#define UPPER (UINT64_C(1) << 63)

struct answer { int status; size_t used, result; };

static int init(void)
{
    const struct { size_t base, capacity; int null_state, status; } rows[] = {
        {17, 64, 0, 0}, {0, 0, 0, 0}, {0, 1, 0, -EINVAL},
        {MAX - 4, 4, 0, 0}, {MAX - 4, 5, 0, -EOVERFLOW},
        {MAX, 0, 0, 0}, {MAX, 1, 0, -EOVERFLOW}, {13, 1, 1, -EINVAL},
    };
    for (size_t i = 0; i < sizeof rows / sizeof rows[0]; ++i) {
        size_t state[] = {19, 37, 59};
        errno = EDOM;
        int status = arena_init(rows[i].null_state ? NULL : state,
                                (void *)(uintptr_t)rows[i].base, rows[i].capacity);
        size_t base = status ? 19 : rows[i].base, capacity = status ? 37 : rows[i].capacity;
        if (status != rows[i].status || state[0] != base || state[1] != capacity ||
            state[2] != (status ? 59u : 0u) || errno != EDOM)
            return 11 + (int)i;
    }
    return 0;
}

static int alloc(void)
{
    const struct {
        size_t base, capacity, used, size, alignment;
        int absent;
        struct answer expected;
    } rows[] = {
        {17, 64, 3, 5, 8, 0, {0, 12, 24}},
        {17, 64, 3, 0, 8, 0, {0, 3, 24}},
        {16, 16, 8, 8, 8, 0, {0, 16, 24}},
        {16, 16, 16, 0, 8, 0, {0, 16, 32}},
        {0, 0, 0, 0, 8, 0, {0, 0, 0}},
        {0, 0, 0, 1, 8, 0, {-ENOSPC, 0, 0}},
        {16, 16, 16, 1, 1, 0, {-ENOSPC, 0, 0}},
        {17, 6, 0, 0, 8, 0, {-ENOSPC, 0, 0}},
        {17, 7, 0, 0, 8, 0, {0, 0, 24}},
        {16, 16, 0, 1, 0, 0, {-EINVAL, 0, 0}},
        {16, 16, 0, 1, 3, 0, {-EINVAL, 0, 0}},
        {16, 16, 0, 1, 1, 1, {-EINVAL, 0, 0}},
        {16, 16, 0, 1, 1, 2, {-EINVAL, 0, 0}},
        {16, 16, 17, 1, 1, 0, {-EINVAL, 0, 0}},
        {0, 1, 0, 1, 1, 0, {-EINVAL, 0, 0}},
        {MAX - 4, 5, 0, 0, 1, 0, {-EOVERFLOW, 0, 0}},
        {MAX - 4, 4, 4, 0, 2, 0, {-EOVERFLOW, 0, 0}},
        {16, 16, 1, MAX, 1, 0, {-EOVERFLOW, 0, 0}},
        {16, 16, 1, MAX - 1, 1, 0, {-ENOSPC, 0, 0}},
        {1, UPPER, 0, 1, UPPER, 0, {0, UPPER, UPPER}},
        {UPPER, UPPER - 1, 0, 1, UPPER, 0, {0, 1, UPPER}},
        {MAX, 0, 0, 0, 1, 0, {0, 0, MAX}},
        {MAX - 8, 8, 0, 0, 8, 0, {0, 0, MAX - 7}},
        {16, 15, 7, 8, 8, 0, {-ENOSPC, 0, 0}},
        {16, 16, 7, 8, 8, 0, {0, 16, 24}},
    };
    for (size_t i = 0; i < sizeof rows / sizeof rows[0]; ++i) {
        size_t state[] = {rows[i].base, rows[i].capacity, rows[i].used};
        void *result = (void *)(uintptr_t)0x19b45;
        errno = EDOM;
        int status = arena_alloc(rows[i].absent == 1 ? NULL : state, rows[i].size, rows[i].alignment,
                                 rows[i].absent == 2 ? NULL : &result);
        const struct answer expected = rows[i].expected;
        if (status != expected.status || errno != EDOM || state[0] != rows[i].base ||
            state[1] != rows[i].capacity || state[2] != (status ? rows[i].used : expected.used) ||
            (uintptr_t)result != (status ? 0x19b45u : expected.result))
            return 11 + (int)i;
    }
    return 0;
}

static int reset(void)
{
    size_t state[] = {MAX, 1, 257};
    errno = EDOM;
    if (arena_reset(state) || state[0] != MAX || state[1] != 1 || state[2] || errno != EDOM)
        return 11;
    return arena_reset(NULL) == -EINVAL && errno == EDOM ? 0 : 12;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "init"))
        return init();
    if (!strcmp(argv[1], "alloc"))
        return alloc();
    if (!strcmp(argv[1], "reset"))
        return reset();
    return 91;
}
