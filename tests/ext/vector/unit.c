#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <vector.h>

enum { DATA, COUNT, CAPACITY, WIDTH, ALIGNMENT };
static _Alignas(16) unsigned char old[48], fresh[128];
static size_t state[5], arena[3];

static void prepare(size_t count, size_t capacity, size_t available)
{
    for (unsigned i = 0; i < sizeof old; ++i)
        old[i] = (unsigned char)(i * 3 + 1);
    memset(fresh, 0xcc, sizeof fresh);
    state[DATA] = capacity ? (uintptr_t)old : 0;
    state[COUNT] = count;
    state[CAPACITY] = capacity;
    state[WIDTH] = 8;
    state[ALIGNMENT] = 8;
    arena[0] = (uintptr_t)(fresh + 1);
    arena[1] = available;
    arena[2] = 2;
    errno = EDOM;
}

static int equals_state(size_t *observed, size_t data, size_t count, size_t capacity)
{
    return observed[DATA] == data && observed[COUNT] == count && observed[CAPACITY] == capacity &&
           observed[WIDTH] == 8 && observed[ALIGNMENT] == 8 && errno == EDOM;
}

static int initial(void)
{
    const struct { size_t width, alignment; int absent, result; } rows[] = {
        {8, 8, 0, 0}, {24, 8, 0, 0}, {1, 1, 0, 0}, {8, 4, 0, 0},
        {0, 1, 0, -EINVAL}, {1, 0, 0, -EINVAL}, {24, 3, 0, -EINVAL},
        {12, 8, 0, -EINVAL}, {8, 8, 1, -EINVAL},
        {(size_t)1 << 63, (size_t)1 << 63, 0, 0},
        {SIZE_MAX, 1, 0, 0}, {SIZE_MAX, 2, 0, -EINVAL},
    };
    for (size_t i = 0; i < sizeof rows / sizeof rows[0]; ++i) {
        size_t value[5] = {17, 19, 23, 29, 31};
        const size_t before[5] = {17, 19, 23, 29, 31};
        const size_t expected[5] = {0, 0, 0, rows[i].width, rows[i].alignment};
        errno = EDOM;
        int result = vector_init(rows[i].absent ? NULL : value, rows[i].width, rows[i].alignment);
        if (result != rows[i].result || errno != EDOM ||
            memcmp(value, rows[i].result ? before : expected, sizeof value))
            return 11 + (int)i;
    }
    return 0;
}

static int reserve(void)
{
    prepare(2, 2, 64);
    if (vector_reserve(state, arena, 3) || !equals_state(state, (uintptr_t)(fresh + 8), 2, 3) ||
        arena[0] != (uintptr_t)(fresh + 1) || arena[1] != 64 || arena[2] != 31 ||
        memcmp(old, fresh + 8, 16) || fresh[7] != 0xcc || fresh[24] != 0xcc)
        return 11;
    if (vector_reserve(state, NULL, 3) || vector_reserve(state, NULL, 2) ||
        !equals_state(state, (uintptr_t)(fresh + 8), 2, 3) || arena[2] != 31)
        return 12;
    prepare(0, 0, 64);
    if (vector_reserve(state, arena, 1) || !equals_state(state, (uintptr_t)(fresh + 8), 0, 1) ||
        arena[2] != 15 || fresh[8] != 0xcc)
        return 13;
    prepare(2, 2, 22);
    if (vector_reserve(state, arena, 3) != -ENOSPC ||
        !equals_state(state, (uintptr_t)old, 2, 2) || arena[2] != 2 || fresh[8] != 0xcc)
        return 14;
    if (vector_reserve(state, arena, SIZE_MAX / 8 + 1) != -EOVERFLOW ||
        vector_reserve(state, arena, SIZE_MAX) != -EOVERFLOW ||
        !equals_state(state, (uintptr_t)old, 2, 2) || arena[2] != 2)
        return 15;
    if (vector_reserve(NULL, arena, 2) != -EINVAL ||
        vector_reserve(state, NULL, 3) != -EINVAL || errno != EDOM || arena[2] != 2)
        return 16;
    return 0;
}

static volatile sig_atomic_t push_active;

static void reject_push_fault(int signal_number)
{
    (void)signal_number;
    _exit(push_active ? 17 : 93);
}

static int observed_push(size_t *state_arg, size_t *arena_arg, const void *item)
{
    push_active = 1;
    int result = vector_push(state_arg, arena_arg, item);
    push_active = 0;
    return result;
}

static int push(void)
{
    struct sigaction action = {.sa_handler = reject_push_fault};
    if (sigemptyset(&action.sa_mask) || sigaction(SIGSEGV, &action, NULL) ||
        sigaction(SIGBUS, &action, NULL))
        return 92;
    const unsigned char value[8] = {0x2d, 0, 0x80, 0xff, 9, 7, 1, 6};
    prepare(0, 0, 64);
    if (observed_push(state, arena, value) || !equals_state(state, (uintptr_t)(fresh + 8), 1, 1) ||
        arena[2] != 15 || memcmp(fresh + 8, value, 8) || fresh[16] != 0xcc)
        return 11;
    prepare(1, 3, 64);
    if (observed_push(state, NULL, old) || !equals_state(state, (uintptr_t)old, 2, 3) ||
        arena[2] != 2 || memcmp(old, old + 8, 8))
        return 12;
    prepare(2, 2, 64);
    if (observed_push(state, arena, old + 8) || !equals_state(state, (uintptr_t)(fresh + 8), 3, 4) ||
        arena[2] != 39 || memcmp(fresh + 8, old, 16) || memcmp(fresh + 24, old + 8, 8))
        return 13;
    prepare(2, 2, 31);
    if (observed_push(state, arena, old) || !equals_state(state, (uintptr_t)(fresh + 8), 3, 3) ||
        arena[2] != 31 || memcmp(fresh + 8, old, 16) || memcmp(fresh + 24, old, 8))
        return 14;
    prepare(2, 2, 30);
    if (observed_push(state, arena, value) != -ENOSPC || !equals_state(state, (uintptr_t)old, 2, 2) ||
        arena[2] != 2 || fresh[8] != 0xcc)
        return 15;
    if (observed_push(NULL, arena, value) != -EINVAL ||
        observed_push(state, arena, NULL) != -EINVAL || observed_push(state, NULL, value) != -EINVAL ||
        !equals_state(state, (uintptr_t)old, 2, 2) || arena[2] != 2)
        return 16;
    prepare(0, 0, 2);
    if (observed_push(state, arena, value) != -ENOSPC ||
        !equals_state(state, 0, 0, 0) || arena[2] != 2 || fresh[8] != 0xcc)
        return 18;
    return 0;
}

static int pop(void)
{
    unsigned char result[12];
    memset(result, 0xa5, sizeof result);
    prepare(2, 3, 64);
    if (vector_pop(state, result + 2) || !equals_state(state, (uintptr_t)old, 1, 3) ||
        memcmp(result + 2, old + 8, 8) || result[1] != 0xa5 || result[10] != 0xa5)
        return 11;
    unsigned char expected[8];
    memcpy(expected, old, 8);
    if (vector_pop(state, old + 1) || !equals_state(state, (uintptr_t)old, 0, 3) ||
        memcmp(old + 1, expected, 8))
        return 12;
    if (vector_pop(state, NULL) != -ENOENT || vector_pop(state, result) != -ENOENT ||
        result[0] != 0xa5 || !equals_state(state, (uintptr_t)old, 0, 3))
        return 13;
    prepare(1, 2, 64);
    if (vector_pop(state, NULL) || !equals_state(state, (uintptr_t)old, 0, 2))
        return 14;
    if (vector_pop(NULL, result) != -EINVAL || result[0] != 0xa5 || errno != EDOM)
        return 15;
    return 0;
}

static int at(void)
{
    void *output = fresh;
    prepare(2, 3, 64);
    if (vector_at(state, 1, &output) || output != old + 8 ||
        !equals_state(state, (uintptr_t)old, 2, 3))
        return 11;
    if (vector_at(state, 0, &output) || output != old || errno != EDOM)
        return 12;
    if (vector_at(state, 2, &output) != -ERANGE || vector_at(state, SIZE_MAX, &output) != -ERANGE ||
        output != old || !equals_state(state, (uintptr_t)old, 2, 3))
        return 13;
    if (vector_at(NULL, 0, &output) != -EINVAL || vector_at(state, 0, NULL) != -EINVAL ||
        output != old || errno != EDOM)
        return 14;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "init"))
        return initial();
    if (!strcmp(argv[1], "reserve"))
        return reserve();
    if (!strcmp(argv[1], "push"))
        return push();
    if (!strcmp(argv[1], "pop"))
        return pop();
    if (!strcmp(argv[1], "at"))
        return at();
    return 91;
}
