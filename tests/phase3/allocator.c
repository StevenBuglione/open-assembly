#include <errno.h>
#include <stdlib.h>

#include "check.h"

static unsigned char pattern(uint32_t seed, size_t index)
{
    return (unsigned char)(seed ^ (seed >> 9) ^ (index * 29) ^ (index >> 8));
}

static void fill(unsigned char *bytes, size_t length, uint32_t seed)
{
    for (size_t i = 0; i < length; ++i)
        bytes[i] = pattern(seed, i);
}

static int matches(const unsigned char *bytes, size_t length, uint32_t seed)
{
    for (size_t i = 0; i < length; ++i)
        if (bytes[i] != pattern(seed, i))
            return 0;
    return 1;
}

static int zeros(const unsigned char *bytes, size_t length)
{
    for (size_t i = 0; i < length; ++i)
        if (bytes[i])
            return 0;
    return 1;
}

static int check_malloc(void)
{
    errno = ERROR_SENTINEL;
    unsigned char *bytes = malloc(33);
    REQUIRE(aligned(bytes, 16) && errno == ERROR_SENTINEL, 20);
    fill(bytes, 33, 717);
    void *zero_a = malloc(0);
    void *zero_b = malloc(0);
    REQUIRE(aligned(zero_a, 16) && aligned(zero_b, 16) && zero_a != zero_b
            && zero_a != bytes && zero_b != bytes && errno == ERROR_SENTINEL, 21);
    REQUIRE(matches(bytes, 33, 717), 22);
    free(zero_a);
    free(zero_b);
    free(bytes);
    free(NULL);
    REQUIRE(errno == ERROR_SENTINEL, 23);
    REQUIRE(!malloc((size_t)PTRDIFF_MAX + 1) && errno == ENOMEM, 24);
    return 0;
}

static int check_calloc(void)
{
    unsigned char *dirty = malloc(77);
    REQUIRE(dirty, 29);
    fill(dirty, 77, 511);
    free(dirty);
    errno = ERROR_SENTINEL;
    unsigned char *bytes = calloc(11, 7);
    REQUIRE(aligned(bytes, 16) && errno == ERROR_SENTINEL, 30);
    REQUIRE(zeros(bytes, 77), 31);
    fill(bytes, 77, 125);
    void *zero_a = calloc(0, SIZE_MAX);
    void *zero_b = calloc(SIZE_MAX, 0);
    REQUIRE(aligned(zero_a, 16) && aligned(zero_b, 16) && zero_a != zero_b
            && zero_a != bytes && zero_b != bytes && errno == ERROR_SENTINEL, 32);
    REQUIRE(matches(bytes, 77, 125), 33);
    free(zero_a);
    free(zero_b);
    free(bytes);
    REQUIRE(!calloc(SIZE_MAX / 3 + 1, 3) && errno == ENOMEM, 34);
    errno = ERROR_SENTINEL;
    REQUIRE(!calloc((size_t)PTRDIFF_MAX / 2 + 1, 2) && errno == ENOMEM, 35);
    return 0;
}

static int check_realloc(void)
{
    errno = ERROR_SENTINEL;
    unsigned char *bytes = realloc(NULL, 77);
    REQUIRE(aligned(bytes, 16) && errno == ERROR_SENTINEL, 40);
    fill(bytes, 77, 511);
    unsigned char *replacement = realloc(bytes, 17);
    REQUIRE(aligned(replacement, 16) && errno == ERROR_SENTINEL && matches(replacement, 17, 511), 41);
    bytes = replacement;
    replacement = realloc(bytes, LARGE_REQUEST);
    REQUIRE(aligned(replacement, 16) && errno == ERROR_SENTINEL && matches(replacement, 17, 511), 42);
    bytes = replacement;
    fill(bytes, LARGE_REQUEST, 991);
    REQUIRE(!realloc(bytes, SIZE_MAX) && errno == ENOMEM && matches(bytes, LARGE_REQUEST, 991), 43);
    errno = ERROR_SENTINEL;
    replacement = realloc(bytes, 0);
    REQUIRE(aligned(replacement, 16) && errno == ERROR_SENTINEL, 44);
    free(replacement);
    return 0;
}

static int check_aligned(void)
{
    static const size_t alignments[] = {1, 2, 4, 8, 16, 32, 64, 512, 4096, 65536};
    for (size_t i = 0; i < sizeof alignments / sizeof alignments[0]; ++i) {
        size_t alignment = alignments[i];
        errno = ERROR_SENTINEL;
        unsigned char *bytes = aligned_alloc(alignment, 19);
        REQUIRE(aligned(bytes, 16) && aligned(bytes, alignment) && errno == ERROR_SENTINEL, 50);
        fill(bytes, 19, (uint32_t)alignment);
        REQUIRE(matches(bytes, 19, (uint32_t)alignment), 51);
        free(bytes);
    }
    void *zero = aligned_alloc(256, 0);
    REQUIRE(aligned(zero, 256), 52);
    free(zero);
    REQUIRE(!aligned_alloc(0, 19) && errno == EINVAL, 53);
    REQUIRE(!aligned_alloc(3, 19) && errno == EINVAL, 54);
    REQUIRE(!aligned_alloc(16, SIZE_MAX) && errno == ENOMEM, 55);
    REQUIRE(!aligned_alloc((size_t)1 << 63, 17) && errno == ENOMEM, 56);
    return 0;
}

static int check_posix(void)
{
    unsigned char marker = 0;
    static const size_t invalid[] = {0, 1, 4, 6, 12, 24};
    errno = ERROR_SENTINEL;
    void *out = &marker;
    for (size_t i = 0; i < sizeof invalid / sizeof invalid[0]; ++i)
        REQUIRE(posix_memalign(&out, invalid[i], 23) == EINVAL && out == &marker
                && errno == ERROR_SENTINEL, 60);
    REQUIRE(posix_memalign(&out, 64, SIZE_MAX) == ENOMEM && out == &marker
            && errno == ERROR_SENTINEL, 61);
    REQUIRE(posix_memalign(&out, 4096, 23) == 0 && out != &marker
            && aligned(out, 4096) && errno == ERROR_SENTINEL, 62);
    fill(out, 23, 724);
    REQUIRE(matches(out, 23, 724), 63);
    free(out);
    out = &marker;
    REQUIRE(posix_memalign(&out, 8, 0) == 0 && out != &marker
            && aligned(out, 16) && errno == ERROR_SENTINEL, 64);
    free(out);
    return 0;
}

struct allocation {
    unsigned char *data;
    size_t size;
    uint32_t seed;
};

enum { SLOT_COUNT = 64, OPERATIONS = 6144 };
static struct allocation slots[SLOT_COUNT];

static int intersects(const struct allocation *a, const struct allocation *b)
{
    uintptr_t left = (uintptr_t)a->data, right = (uintptr_t)b->data;
    size_t left_size = a->size ? a->size : 1;
    size_t right_size = b->size ? b->size : 1;
    return left <= right ? right - left < left_size : left - right < right_size;
}

static size_t choose_size(uint32_t word)
{
    static const size_t boundaries[] = {
        0, 1, 7, 8, 15, 16, 17, 31, 32, 33, 47, 48, 49, 63, 64, 65, 79, 80, 81,
        95, 96, 97, 127, 128, 129, 159, 160, 161, 191, 192, 193, 223, 224, 225,
        351, 352, 353, 479, 480, 481, 735, 736, 737, 991, 992, 993,
        1503, 1504, 1505, 2015, 2016, 2017, 3039, 3040, 3041, 4063, 4064, 4065,
        4095, 4096, 4097, 65535, 65536, 65537,
    };
    return word % 3 ? boundaries[(word >> 8) % (sizeof boundaries / sizeof boundaries[0])]
                    : (word >> 10) % 8192;
}

static int run_model(void)
{
    uint32_t state = UINT32_C(0xa3110c31);
    for (size_t step = 0; step < OPERATIONS; ++step) {
        uint32_t word = next(&state);
        size_t index = word % SLOT_COUNT;
        struct allocation *slot = slots + index;
        struct allocation *sample = slots + (next(&state) % SLOT_COUNT);
        REQUIRE(!sample->data || matches(sample->data, sample->size, sample->seed), 70);
        REQUIRE(!slot->data || matches(slot->data, slot->size, slot->seed), 71);
        errno = ERROR_SENTINEL;
        if (slot->data && (word >> 10) % 3 == 0) {
            free(slot->data);
            *slot = (struct allocation){0};
            REQUIRE(errno == ERROR_SENTINEL, 72);
            continue;
        }
        size_t size = choose_size(next(&state));
        size_t alignment = 16;
        void *data = NULL;
        if (slot->data) {
            if (step % 23 == 0) {
                REQUIRE(!realloc(slot->data, SIZE_MAX) && errno == ENOMEM
                        && matches(slot->data, slot->size, slot->seed), 73);
                continue;
            }
            data = realloc(slot->data, size);
            size_t retained = size < slot->size ? size : slot->size;
            REQUIRE(data && matches(data, retained, slot->seed), 74);
        } else {
            switch ((word >> 8) % 4) {
            case 0:
                data = malloc(size);
                break;
            case 1:
                data = calloc(size, 1);
                REQUIRE(data && zeros(data, size), 75);
                break;
            case 2:
                alignment = (size_t)1 << (4 + (word >> 16) % 13);
                data = aligned_alloc(alignment, size);
                break;
            default:
                alignment = (size_t)1 << (4 + (word >> 16) % 13);
                REQUIRE(posix_memalign(&data, alignment, size) == 0, 76);
                break;
            }
        }
        REQUIRE(aligned(data, alignment) && errno == ERROR_SENTINEL, 77);
        *slot = (struct allocation){data, size, next(&state)};
        for (size_t j = 0; j < SLOT_COUNT; ++j)
            REQUIRE(j == index || !slots[j].data || !intersects(slot, slots + j), 78);
        fill(data, size, slot->seed);
    }
    for (size_t i = 0; i < SLOT_COUNT; ++i) {
        REQUIRE(!slots[i].data || matches(slots[i].data, slots[i].size, slots[i].seed), 79);
        free(slots[i].data);
    }
    return 0;
}

enum { TINY_COUNT = 3400 };
static unsigned char *tiny[TINY_COUNT];

static int slab_churn(void)
{
    for (size_t pass = 0; pass < 2; ++pass) {
        for (size_t i = pass; i < TINY_COUNT; i += pass + 1) {
            size_t size = 1 + i % 16;
            unsigned char *bytes = pass ? calloc(size, 1) : malloc(size);
            REQUIRE(aligned(bytes, 16), 90);
            for (size_t j = 0; j < TINY_COUNT; ++j)
                REQUIRE(tiny[j] != bytes, 91);
            if (pass)
                REQUIRE(zeros(bytes, size), 92);
            fill(bytes, size, (uint32_t)i);
            tiny[i] = bytes;
        }
        if (!pass) {
            for (size_t i = 1; i < TINY_COUNT; i += 2) {
                REQUIRE(matches(tiny[i], 1 + i % 16, (uint32_t)i), 93);
                free(tiny[i]);
                tiny[i] = NULL;
            }
        }
    }
    for (size_t i = TINY_COUNT; i; --i) {
        REQUIRE(matches(tiny[i - 1], 1 + (i - 1) % 16, (uint32_t)(i - 1)), 94);
        free(tiny[i - 1]);
    }
    return 0;
}

int main(int argc, char **argv)
{
    REQUIRE(argc == 2, 10);
    if (same(argv[1], "malloc"))
        return check_malloc();
    if (same(argv[1], "calloc"))
        return check_calloc();
    if (same(argv[1], "realloc"))
        return check_realloc();
    if (same(argv[1], "aligned"))
        return check_aligned();
    if (same(argv[1], "posix"))
        return check_posix();
    if (same(argv[1], "model"))
        return run_model();
    if (same(argv[1], "slab-churn"))
        return slab_churn();
    return 11;
}
