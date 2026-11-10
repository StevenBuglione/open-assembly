#include <errno.h>
#include <map.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

struct input { uint64_t flags, seed, keys, value; };
struct result {
    int64_t status;
    uint64_t error, table, capacity, count, seed, used, output;
    size_t slots[4][4];
    unsigned char arena[24];
};
_Static_assert(sizeof(struct input) == 32 && sizeof(struct result) == 216, "LP64 packet widths");

enum { INIT, PROBE, GET, PUT, REMOVE };
enum { MARKER, KEY, LENGTH, VALUE };

static uint64_t placement(uint64_t seed, const unsigned char *key, size_t length)
{
    uint64_t hash = seed ^ length ^ UINT64_C(0xd915b31d72a14e87);
    for (size_t i = 0; i < length; ++i) {
        hash = (hash + key[i] + 1) * UINT64_C(0xb7192a6f49d38be5);
        hash ^= hash >> 27;
    }
    hash = (hash ^ (hash >> 23)) * UINT64_C(0x9be540c7d2f163a9);
    return hash ^ (hash >> 31);
}

static void initialize(const struct input *input, struct result *output)
{
    size_t slots[16];
    for (size_t i = 0; i < sizeof slots / sizeof *slots; ++i)
        slots[i] = UINT64_C(0x9985172521);
    size_t state[] = {13, 17, 19, 23};
    unsigned mode = (unsigned)(input->flags % 8);
    size_t capacity = (size_t)1 << ((input->flags >> 4) % 3);
    if (mode == 1)
        capacity = 0;
    else if (mode == 2)
        capacity = 3;
    else if (mode == 3)
        capacity = (size_t)1 << 59;
    size_t *storage = mode == 4 ? NULL : mode == 5 ? (size_t *)(uintptr_t)(SIZE_MAX - 15) : slots;
    if (mode == 5)
        capacity = 1;
    errno = EDOM;
    output->status = map_init(mode == 6 ? NULL : state, storage, capacity, input->seed);
    output->error = (uint64_t)errno;
    output->table = state[0] == (uintptr_t)slots ? 1 : state[0];
    output->capacity = state[1];
    output->count = state[2];
    output->seed = state[3];
    memcpy(output->slots, slots, sizeof slots);
}

static void operate(unsigned operation, const struct input *input, struct result *output)
{
    size_t slots[4][4] = {{0}};
    unsigned char backing[24];
    memset(backing, 0xcc, sizeof backing);
    size_t capacity = (size_t)1 << ((input->flags >> 4) % 3);
    size_t count = (input->flags >> 8) % (capacity + 1);
    size_t state[] = {(uintptr_t)slots, capacity, count, input->seed};
    size_t arena[] = {(uintptr_t)backing, 3 * count + (input->value & 7), 3 * count};
    unsigned char key_data[4][3];
    size_t key_lengths[4], first = 0;
    for (size_t i = 0; i < 4; ++i) {
        key_data[i][0] = (unsigned char)(input->keys >> (i * 8));
        key_data[i][1] = (unsigned char)i;
        key_data[i][2] = 0x80;
        key_lengths[i] = 2 + (input->flags >> (16 + i) & 1);
    }
    for (size_t i = 0; i < count; ++i) {
        size_t index = placement(input->seed, key_data[i], key_lengths[i]) % capacity;
        while (slots[index][MARKER])
            index = (index + 1) % capacity;
        memcpy(backing + 3 * i, key_data[i], key_lengths[i]);
        slots[index][MARKER] = 2;
        slots[index][KEY] = (uintptr_t)(backing + 3 * i);
        slots[index][LENGTH] = key_lengths[i];
        slots[index][VALUE] = input->value ^ i;
        if (!i)
            first = index;
    }
    if (count && (input->flags & (1u << 12))) {
        memset(slots[first], 0, sizeof slots[first]);
        slots[first][MARKER] = 1;
        --state[2];
    }
    unsigned mode = (unsigned)(input->flags % 16);
    unsigned char missing[] = {0x67, 0xe1, (unsigned char)(input->keys >> 32)};
    size_t index = count ? input->keys % count : 0;
    const unsigned char *key = count && mode != 1 ? key_data[index] : missing;
    size_t length = count && mode != 1 ? key_lengths[index] : sizeof missing;
    if (mode == 2 || mode == 3 || mode == 4) {
        key = mode == 4 ? (const unsigned char *)(uintptr_t)(SIZE_MAX - 1) : NULL;
        length = mode == 2 ? 0 : 2;
    }
    size_t *target = mode == 5 ? NULL : state;
    size_t value = UINT64_C(0x918501664fc00123);
    errno = EDOM;
    switch (operation) {
    case PROBE: output->status = map_probe(target, key, length); break;
    case GET: output->status = map_get(target, key, length, mode == 6 ? NULL : &value); break;
    case PUT: output->status = map_put(target, mode == 6 ? NULL : arena, key, length, input->value); break;
    default: output->status = map_remove(target, key, length, mode == 6 ? NULL : &value); break;
    }
    output->error = (uint64_t)errno;
    output->table = state[0] == (uintptr_t)slots ? 1 : state[0];
    output->capacity = state[1];
    output->count = state[2];
    output->seed = state[3];
    output->used = arena[2];
    output->output = value;
    for (size_t i = 0; i < 4; ++i) {
        if (slots[i][MARKER] == 2) {
            uintptr_t key_pointer = slots[i][KEY], base = (uintptr_t)backing;
            slots[i][KEY] = !slots[i][LENGTH] ? 0 :
                key_pointer >= base && key_pointer - base < sizeof backing ? key_pointer - base + 1 : UINT64_MAX;
        }
    }
    memcpy(output->slots, slots, sizeof slots);
    memcpy(output->arena, backing, sizeof backing);
}

static int transfer(void *memory, size_t size, int writing)
{
    size_t offset = 0;
    while (offset < size) {
        unsigned char *bytes = (unsigned char *)memory + offset;
        ssize_t count = writing ? write(STDOUT_FILENO, bytes, size - offset) :
                                  read(STDIN_FILENO, bytes, size - offset);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            return count == 0 && !offset && !writing ? 0 : -1;
        offset += (size_t)count;
    }
    return 1;
}

int main(int argc, char **argv)
{
    const char *modes[] = {"init", "probe", "get", "put", "remove"};
    if (argc != 2)
        return 90;
    unsigned operation = 0;
    while (operation < sizeof modes / sizeof *modes && strcmp(argv[1], modes[operation]))
        ++operation;
    if (operation == sizeof modes / sizeof *modes)
        return 91;
    struct input input;
    int received;
    while ((received = transfer(&input, sizeof input, 0)) == 1) {
        struct result output = {0};
        if (operation == INIT)
            initialize(&input, &output);
        else
            operate(operation, &input, &output);
        if (transfer(&output, sizeof output, 1) != 1)
            return 92;
    }
    return received < 0 ? 93 : 0;
}
