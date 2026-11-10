#include <errno.h>
#include <map.h>
#include <stdint.h>
#include <string.h>

enum { TABLE, CAPACITY, COUNT, SEED };
enum { MARKER, KEY, LENGTH, VALUE };
static const unsigned char keys[] = {1, 4, 5, 6, 7};
static const size_t sentinel = UINT64_C(0x9166a55433221107);
static size_t state[4], slots[16], arena[3];
static unsigned char backing[24];

static size_t *slot(unsigned index) { return slots + 4 * index; }

static void empty(void)
{
    memset(slots, 0, sizeof slots);
    memset(backing, 0xcc, sizeof backing);
    state[TABLE] = (uintptr_t)slots;
    state[CAPACITY] = 4;
    state[COUNT] = state[SEED] = 0;
    arena[0] = (uintptr_t)backing;
    arena[1] = sizeof backing;
    arena[2] = 0;
    errno = EDOM;
}

/* These bytes all have initial slot 3 for the published mixer with seed
   zero and capacity 4. Later insertions cross the end of the table. */
static void fill(unsigned count)
{
    empty();
    for (unsigned i = 0; i < count; ++i) {
        size_t *item = slot((i + 3) % 4);
        backing[i] = keys[i];
        item[MARKER] = 2;
        item[KEY] = (uintptr_t)(backing + i);
        item[LENGTH] = 1;
        item[VALUE] = sentinel + i;
    }
    state[COUNT] = arena[2] = count;
}

static void remove_first(void)
{
    memset(slot(3), 0, 4 * sizeof *slots);
    slot(3)[MARKER] = 1;
    --state[COUNT];
}

static int initial(void)
{
    const size_t old[] = {11, 13, 17, 19};
    memcpy(state, old, sizeof state);
    for (size_t i = 0; i < sizeof slots / sizeof *slots; ++i)
        slots[i] = sentinel;
    errno = EDOM;
    if (map_init(state, slots, 2, sentinel) || state[TABLE] != (uintptr_t)slots ||
        state[CAPACITY] != 2 || state[COUNT] || state[SEED] != sentinel || errno != EDOM)
        return 11;
    const size_t zeros[8] = {0};
    if (memcmp(slots, zeros, sizeof zeros) || slots[8] != sentinel || slots[15] != sentinel)
        return 12;
    size_t state_before[4], slot_before[16];
    memcpy(state_before, state, sizeof state);
    memcpy(slot_before, slots, sizeof slots);
    const struct { size_t *state, *slot, capacity; int status; } rows[] = {
        {NULL, slots, 4, -EINVAL}, {state, NULL, 4, -EINVAL},
        {state, slots, 0, -EINVAL}, {state, slots, 3, -EINVAL},
        {state, slots, (size_t)1 << 59, -EOVERFLOW},
        {state, (size_t *)(uintptr_t)(SIZE_MAX - 15), 1, -EOVERFLOW},
    };
    for (size_t i = 0; i < sizeof rows / sizeof *rows; ++i)
        if (map_init(rows[i].state, rows[i].slot, rows[i].capacity, 37) != rows[i].status ||
            memcmp(state, state_before, sizeof state) || memcmp(slots, slot_before, sizeof slots) || errno != EDOM)
            return 13 + (int)i;
    if (map_init(state, slots, 1, 37) || state[CAPACITY] != 1 || state[SEED] != 37 || errno != EDOM)
        return 19;
    return 0;
}

static int probe(void)
{
    empty();
    if (map_probe(state, keys, 1) != 6 || errno != EDOM)
        return 11;
    if (map_probe(state, NULL, 0) != 0 || map_probe(state, keys, 0) != 0)
        return 12;
    fill(3);
    if (map_probe(state, keys, 1) != 7 || map_probe(state, keys + 1, 1) != 1 ||
        map_probe(state, keys + 2, 1) != 3 || map_probe(state, keys + 4, 1) != 4)
        return 13;
    if (map_probe(state, keys, 2) != 4)
        return 14;
    fill(4);
    if (map_probe(state, keys + 4, 1) != -ENOSPC)
        return 15;
    remove_first();
    if (map_probe(state, keys + 2, 1) != 3 || map_probe(state, keys + 4, 1) != 6 ||
        errno != EDOM || slot(3)[MARKER] != 1)
        return 16;
    if (map_probe(NULL, keys, 1) != -EINVAL || map_probe(state, NULL, 1) != -EINVAL ||
        map_probe(state, (void *)(uintptr_t)(SIZE_MAX - 1), 2) != -EOVERFLOW || errno != EDOM)
        return 17;
    empty();
    state[SEED] = 1;
    if (map_probe(state, keys, 1) != 0 || errno != EDOM)
        return 18;
    empty();
    slot(0)[MARKER] = 2;
    slot(0)[VALUE] = sentinel;
    state[COUNT] = 1;
    if (map_probe(state, NULL, 0) != 1 || map_probe(state, keys, 0) != 1)
        return 19;
    fill(4);
    remove_first();
    if (map_probe(state, keys + 4, 1) != 6)
        return 20;
    memset(slot(0), 0, 4 * sizeof *slots);
    slot(0)[MARKER] = 1;
    --state[COUNT];
    if (map_probe(state, keys + 2, 1) != 3 || map_probe(state, keys + 4, 1) != 6 ||
        state[COUNT] != 2 || slot(3)[MARKER] != 1 || slot(0)[MARKER] != 1 || errno != EDOM)
        return 21;
    empty();
    const unsigned char first = 'k', second = 'l';
    if (map_put(state, arena, &first, 1, 49) || map_remove(state, &first, 1, NULL) ||
        state[COUNT] || slot(0)[MARKER] != 1 || slot(1)[MARKER] ||
        map_probe(state, &second, 1) != 0 || errno != EDOM)
        return 22;
    return 0;
}

static int get(void)
{
    fill(3);
    size_t value = 0;
    if (map_get(state, keys + 1, 1, &value) || value != sentinel + 1 || errno != EDOM)
        return 11;
    if (map_get(state, keys + 4, 1, &value) != -ENOENT || value != sentinel + 1)
        return 12;
    fill(4);
    if (map_get(state, keys + 4, 1, &value) != -ENOENT || value != sentinel + 1)
        return 13;
    if (map_get(state, keys, 1, NULL) != -EINVAL || map_get(NULL, keys, 1, &value) != -EINVAL ||
        map_get(state, NULL, 1, &value) != -EINVAL || errno != EDOM || value != sentinel + 1)
        return 14;
    if (map_get(state, (void *)(uintptr_t)(SIZE_MAX - 1), 2, &value) != -EOVERFLOW ||
        value != sentinel + 1 || errno != EDOM)
        return 15;
    return 0;
}

static int put(void)
{
    empty();
    unsigned char user_key[] = {0, 0x80, 0xff};
    const unsigned char original[] = {0, 0x80, 0xff};
    if (map_put(state, arena, user_key, sizeof user_key, sentinel) || state[COUNT] != 1 ||
        arena[2] != 3 || slot(3)[MARKER] != 2 || slot(3)[KEY] != (uintptr_t)backing ||
        slot(3)[LENGTH] != sizeof user_key || slot(3)[VALUE] != sentinel || errno != EDOM ||
        memcmp(backing, original, sizeof original) || backing[3] != 0xcc)
        return 11;
    memset(user_key, 0x33, sizeof user_key);
    if (map_put(state, NULL, original, sizeof original, sentinel + 1) ||
        slot(3)[VALUE] != sentinel + 1 || memcmp(backing, original, sizeof original) ||
        state[COUNT] != 1 || arena[2] != 3 || errno != EDOM)
        return 12;
    if (map_put(state, NULL, NULL, 0, 37) || slot(0)[MARKER] != 2 ||
        slot(0)[LENGTH] || slot(0)[VALUE] != 37 || state[COUNT] != 2 || arena[2] != 3)
        return 13;
    fill(4);
    if (map_put(state, NULL, keys + 2, 1, 29) || slot(1)[VALUE] != 29 ||
        map_put(state, arena, keys + 4, 1, 1) != -ENOSPC || state[COUNT] != 4 || arena[2] != 4)
        return 14;
    fill(3);
    remove_first();
    if (map_put(state, arena, keys + 4, 1, 3) || slot(3)[VALUE] != 3 ||
        slot(3)[KEY] != (uintptr_t)(backing + 3) || backing[3] != keys[4] || state[COUNT] != 3)
        return 15;
    size_t old[16];
    memcpy(old, slots, sizeof old);
    arena[1] = arena[2];
    if (map_put(state, arena, keys + 3, 1, 1) != -ENOSPC ||
        map_put(state, NULL, keys + 3, 1, 1) != -EINVAL ||
        map_put(state, arena, NULL, 1, 1) != -EINVAL || map_put(NULL, arena, keys, 1, 1) != -EINVAL ||
        map_put(state, arena, (void *)(uintptr_t)(SIZE_MAX - 1), 2, 1) != -EOVERFLOW ||
        memcmp(old, slots, sizeof old) || state[COUNT] != 3 || arena[2] != 4 || errno != EDOM)
        return 16;
    return 0;
}

static int remove_key(void)
{
    fill(3);
    size_t value = 0;
    if (map_remove(state, keys, 1, &value) || value != sentinel || state[COUNT] != 2 ||
        slot(3)[MARKER] != 1 || slot(3)[KEY] || slot(3)[LENGTH] || slot(3)[VALUE] ||
        arena[2] != 3 || memcmp(backing, keys, 3) || errno != EDOM)
        return 11;
    if (map_remove(state, keys + 2, 1, NULL) || state[COUNT] != 1 || slot(1)[MARKER] != 1 ||
        errno != EDOM || arena[2] != 3)
        return 12;
    if (map_remove(state, keys, 1, &value) != -ENOENT || value != sentinel || state[COUNT] != 1)
        return 13;
    fill(4);
    if (map_remove(state, keys + 4, 1, &value) != -ENOENT || value != sentinel || state[COUNT] != 4)
        return 14;
    if (map_remove(NULL, keys, 1, &value) != -EINVAL || map_remove(state, NULL, 1, &value) != -EINVAL ||
        map_remove(state, (void *)(uintptr_t)(SIZE_MAX - 1), 2, &value) != -EOVERFLOW ||
        value != sentinel || errno != EDOM)
        return 15;
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 2)
        return 90;
    if (!strcmp(argv[1], "init"))
        return initial();
    if (!strcmp(argv[1], "probe"))
        return probe();
    if (!strcmp(argv[1], "get"))
        return get();
    if (!strcmp(argv[1], "put"))
        return put();
    if (!strcmp(argv[1], "remove"))
        return remove_key();
    return 91;
}
