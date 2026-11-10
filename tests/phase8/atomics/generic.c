#include <compiler_rt.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>

extern long __al_syscall(long, long, long, long, long, long, long);

enum { PAGE = 4096, LOAD, STORE, EXCHANGE, COMPARE, LOCK_FREE, ZERO };

static unsigned char *guarded(void)
{
    long map = __al_syscall(9, 0, 3 * PAGE, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (map < 0 || __al_syscall(10, map + PAGE, PAGE, PROT_READ | PROT_WRITE, 0, 0, 0))
        return NULL;
    return (unsigned char *)(map + PAGE);
}

static int release(unsigned char *middle)
{
    return __al_syscall(11, (long)middle - PAGE, 3 * PAGE, 0, 0, 0, 0) == 0;
}

static unsigned char known(size_t index, unsigned salt)
{
    return (unsigned char)((index * 17u + (index >> 3)) ^ salt);
}

static int expect(const unsigned char *bytes, size_t size, unsigned salt)
{
    for (size_t i = 0; i < size; ++i)
        if (bytes[i] != known(i, salt))
            return 0;
    return 1;
}

static int bytes_case(unsigned operation, unsigned char *object, unsigned char *source,
                      unsigned char *output, size_t size)
{
    for (size_t i = 0; i < size; ++i) {
        object[i] = known(i, 0x5au);
        source[i] = known(i, 0xc3u);
        output[i] = known(i, 0x96u);
    }
    errno = EDOM;
    if (operation == LOAD) {
        __al_abi_atomic_load(size, object, output, __ATOMIC_ACQUIRE);
        return expect(output, size, 0x5au) && expect(object, size, 0x5au) && errno == EDOM ? 0 : 11;
    }
    if (operation == STORE) {
        __al_abi_atomic_store(size, object, source, __ATOMIC_RELEASE);
        return expect(object, size, 0xc3u) && expect(source, size, 0xc3u) && errno == EDOM ? 0 : 12;
    }
    if (operation == EXCHANGE) {
        __al_abi_atomic_exchange(size, object, source, output, __ATOMIC_RELAXED);
        return expect(object, size, 0xc3u) && expect(source, size, 0xc3u) &&
               expect(output, size, 0x5au) && errno == EDOM ? 0 : 13;
    }

    if (__al_abi_atomic_compare_exchange(size, object, output, source, __ATOMIC_SEQ_CST, __ATOMIC_ACQUIRE) ||
        !expect(object, size, 0x5au) || !expect(output, size, 0x5au) ||
        !expect(source, size, 0xc3u) || errno != EDOM)
        return 14;
    if (!__al_abi_atomic_compare_exchange(size, object, output, source, __ATOMIC_SEQ_CST, __ATOMIC_ACQUIRE) ||
        !expect(object, size, 0xc3u) || !expect(output, size, 0x5au) ||
        !expect(source, size, 0xc3u) || errno != EDOM)
        return 15;
    return 0;
}

static int guarded_bytes(unsigned operation)
{
    unsigned char *object = guarded(), *source = guarded(), *output = guarded();
    if (!object || !source || !output)
        return 90;
    const size_t widths[] = {1, 2, 3, 4, 5, 8, 9, 16, 24, 127, PAGE};
    for (int right = 0; right < 2; ++right)
        for (size_t i = 0; i < sizeof widths / sizeof widths[0]; ++i) {
            size_t size = widths[i], offset = right ? PAGE - size : 0;
            int status = bytes_case(operation, object + offset, source + offset, output + offset, size);
            if (status)
                return status;
        }
    int status = bytes_case(operation, object + 1, source + 3, output + 5, 8);
    return release(object) && release(source) && release(output) ? status : 90;
}

static int overlap(void)
{
    _Alignas(16) unsigned char object[24], buffers[28], expected[28];
    const size_t widths[] = {1, 2, 4, 8, 16, 24};
    for (size_t i = 0; i < sizeof widths / sizeof widths[0]; ++i) {
        size_t size = widths[i];
        const unsigned positions[][2] = {{1, 1}, {1, 2}, {2, 1}};
        for (size_t direction = 0; direction < 3; ++direction) {
            unsigned in = positions[direction][0], out = positions[direction][1];
            for (size_t j = 0; j < sizeof buffers; ++j)
                buffers[j] = expected[j] = known(j, 0x7eu);
            for (size_t j = 0; j < size; ++j) {
                object[j] = known(j, 0x81u);
                expected[out + j] = object[j];
            }
            unsigned char input[24];
            memcpy(input, buffers + in, size);
            errno = EDOM;
            __al_abi_atomic_exchange(size, object, buffers + in, buffers + out, __ATOMIC_SEQ_CST);
            if (memcmp(object, input, size) || memcmp(buffers, expected, sizeof buffers) || errno != EDOM)
                return 17;
        }
    }
    return 0;
}

static int classification(int zero_only)
{
    unsigned char *memory = guarded();
    if (!memory)
        return 90;
    unsigned char *unreadable = memory - PAGE;
    errno = EDOM;
    if (zero_only) {
        __al_abi_atomic_load(0, unreadable, unreadable + 1, __ATOMIC_SEQ_CST);
        __al_abi_atomic_store(0, unreadable, unreadable + 1, __ATOMIC_SEQ_CST);
        __al_abi_atomic_exchange(0, unreadable, unreadable + 1, unreadable + 2, __ATOMIC_SEQ_CST);
        if (!__al_abi_atomic_compare_exchange(0, unreadable, unreadable + 1, unreadable + 2,
                                              __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST) || errno != EDOM)
            return 18;
    } else {
        for (size_t width = 1; width <= 8; width *= 2) {
            if (!__al_abi_atomic_is_lock_free(width, unreadable) || !__al_abi_atomic_is_lock_free(width, NULL) ||
                (width > 1 && __al_abi_atomic_is_lock_free(width, memory + 1)) || errno != EDOM)
                return 16;
        }
        if (__al_abi_atomic_is_lock_free(0, unreadable) || __al_abi_atomic_is_lock_free(3, unreadable) ||
            __al_abi_atomic_is_lock_free(16, unreadable) || __al_abi_atomic_is_lock_free(SIZE_MAX, unreadable) ||
            errno != EDOM)
            return 19;
    }
    return release(memory) ? 0 : 90;
}

int main(int argc, char **argv)
{
    static const char *const modes[] = {"load", "store", "exchange", "compare", "lock-free", "zero"};
    if (argc != 2)
        return 90;
    for (unsigned i = 0; i < sizeof modes / sizeof modes[0]; ++i) {
        if (strcmp(argv[1], modes[i]))
            continue;
        unsigned operation = LOAD + i;
        if (operation == LOCK_FREE || operation == ZERO)
            return classification(operation == ZERO);
        return guarded_bytes(operation);
    }
    if (!strcmp(argv[1], "overlap"))
        return overlap();
    return 91;
}
