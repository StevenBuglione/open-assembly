#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <vector.h>

struct request { uint64_t flags, dimensions, limits, content; };
struct reply {
    int64_t status;
    uint64_t error, address, count, capacity, width, alignment, arena_used, output;
    unsigned char old[64], fresh[80];
};
_Static_assert(sizeof(struct request) == 32 && sizeof(struct reply) == 216, "LP64 packet ABI");

enum { INIT, RESERVE, PUSH, POP, AT };

static uint64_t offset(void *value, const unsigned char *old, const unsigned char *fresh)
{
    uintptr_t pointer = (uintptr_t)value;
    uintptr_t old_base = (uintptr_t)old, fresh_base = (uintptr_t)fresh;
    if (!pointer)
        return 0;
    if (pointer >= old_base && pointer - old_base < 64)
        return 1 + pointer - old_base;
    if (pointer >= fresh_base && pointer - fresh_base < 80)
        return 129 + pointer - fresh_base;
    return UINT64_MAX;
}

static void observe(unsigned operation, const struct request *input, struct reply *reply)
{
    _Alignas(16) unsigned char old[64], fresh[80];
    for (size_t i = 0; i < sizeof old; ++i)
        old[i] = (unsigned char)(input->content >> (i % 8 * 8)) ^ (unsigned char)(i * 29 + 73);
    memset(fresh, 0xcc, sizeof fresh);

    unsigned mode = (unsigned)(input->flags & 7);
    unsigned power = (unsigned)(input->dimensions & 3);
    if (operation == RESERVE && mode == 3 && !power)
        power = 1;
    size_t width = (size_t)1 << power;
    size_t alignment = (size_t)1 << ((input->dimensions >> 4) % (power + 1));
    size_t count = (input->dimensions >> 8) & 3;
    size_t capacity = count + ((input->dimensions >> 12) & 3);
    size_t state[] = {capacity ? (uintptr_t)old : 0, count, capacity, width, alignment};
    size_t arena[] = {(uintptr_t)(fresh + 1), (input->limits & 63) + 8, (input->limits >> 8) & 7};
    uint64_t output = UINT64_C(0xa5a5a5a5a5a5a5a5);
    errno = EDOM;
    int status;
    switch (operation) {
    case INIT: {
        size_t requested_width = mode == 1 ? 0 : mode == 4 ? 9 : width;
        size_t requested_alignment = mode == 2 ? 0 : mode == 3 ? 3 : mode == 4 ? 8 : alignment;
        status = vector_init(mode == 5 ? NULL : state, requested_width, requested_alignment);
        break;
    }
    case RESERVE: {
        size_t requested = mode == 1 ? capacity : mode == 2 ? capacity + 1 :
                           mode == 3 ? SIZE_MAX : (input->limits >> 16) % 9;
        status = vector_reserve(mode == 4 ? NULL : state,
                                mode == 1 || mode == 2 ? NULL : arena, requested);
        break;
    }
    case PUSH: {
        const void *item = mode == 1 && count ? (const void *)(old + (count - 1) * width) : &input->content;
        status = vector_push(mode == 2 ? NULL : state, mode == 4 ? NULL : arena,
                             mode == 3 ? NULL : item);
        break;
    }
    case POP: {
        void *destination = &output;
        if (mode == 1)
            destination = NULL;
        else if (mode == 2 && count)
            destination = old + (count - 1) * width + 1;
        status = vector_pop(mode == 3 ? NULL : state, destination);
        break;
    }
    default: {
        void *result = fresh + 79;
        size_t index = (input->limits >> 16) % 8;
        status = vector_at(mode == 1 ? NULL : state, index, mode == 2 ? NULL : &result);
        output = offset(result, old, fresh);
        break;
    }
    }
    *reply = (struct reply){status, (uint64_t)errno, offset((void *)(uintptr_t)state[0], old, fresh),
                            state[1], state[2], state[3], state[4], arena[2], output, {0}, {0}};
    memcpy(reply->old, old, sizeof old);
    memcpy(reply->fresh, fresh, sizeof fresh);
}

static int transfer(void *bytes, size_t size, int writing)
{
    size_t done = 0;
    while (done < size) {
        unsigned char *cursor = (unsigned char *)bytes + done;
        ssize_t count = writing ? write(STDOUT_FILENO, cursor, size - done) :
                                  read(STDIN_FILENO, cursor, size - done);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            return count == 0 && !done && !writing ? 0 : -1;
        done += (size_t)count;
    }
    return 1;
}

int main(int argc, char **argv)
{
    const char *operations[] = {"init", "reserve", "push", "pop", "at"};
    if (argc != 2)
        return 90;
    unsigned operation = 0;
    while (operation < sizeof operations / sizeof *operations && strcmp(argv[1], operations[operation]))
        ++operation;
    if (operation == sizeof operations / sizeof *operations)
        return 91;
    struct request input;
    int result;
    while ((result = transfer(&input, sizeof input, 0)) == 1) {
        struct reply reply;
        observe(operation, &input, &reply);
        if (transfer(&reply, sizeof reply, 1) != 1)
            return 92;
    }
    return result < 0 ? 93 : 0;
}
