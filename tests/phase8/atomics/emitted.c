#include <errno.h>
#include <stdatomic.h>
#include <stdint.h>
#include <string.h>

typedef unsigned __int128 wide;
typedef struct { unsigned char bytes[3]; } tiny;
typedef struct { uint64_t lanes[3]; } large;

static tiny tiny_object;
static _Atomic(large) large_object;
static _Alignas(16) wide wide_object;
static _Alignas(8) uint64_t native_word;
static volatile size_t size_for_query = 8;

static int aggregates(void)
{
    tiny first = {{0x0a, 0xb2, 0xf7}}, second = {{0x23, 0xf9, 0x4d}};
    __atomic_store(&tiny_object, &first, __ATOMIC_RELEASE);
    tiny previous;
    __atomic_exchange(&tiny_object, &second, &previous, __ATOMIC_SEQ_CST);
    if (memcmp(&previous, &first, sizeof first))
        return 11;
    tiny expected = first;
    if (__atomic_compare_exchange(&tiny_object, &expected, &first, 0, __ATOMIC_SEQ_CST, __ATOMIC_ACQUIRE) ||
        memcmp(&expected, &second, sizeof second))
        return 12;
    if (!__atomic_compare_exchange(&tiny_object, &expected, &first, 0, __ATOMIC_SEQ_CST, __ATOMIC_ACQUIRE))
        return 13;
    __atomic_load(&tiny_object, &previous, __ATOMIC_ACQUIRE);
    if (memcmp(&previous, &first, sizeof first))
        return 14;

    const large a = {{UINT64_C(0xabcce0123456fff7), 29, UINT64_MAX}},
                b = {{27, 0, UINT64_C(0x8711ffeee02d2229)}};
    atomic_store_explicit(&large_object, a, memory_order_release);
    large old = atomic_exchange_explicit(&large_object, b, memory_order_seq_cst);
    if (memcmp(&old, &a, sizeof a))
        return 15;
    large expected_large = b;
    if (!atomic_compare_exchange_strong_explicit(&large_object, &expected_large, a,
                                                  memory_order_seq_cst, memory_order_acquire))
        return 16;
    old = atomic_load_explicit(&large_object, memory_order_acquire);
    return memcmp(&old, &a, sizeof a) ? 17 : 0;
}

static int wide_values(void)
{
    const wide a = ((wide)UINT64_C(0x812444077ce00234) << 64) | UINT64_C(0x10ff8a22ed333410);
    const wide b = ((wide)UINT64_C(0x2c78132d0d221975) << 64) | UINT64_C(0xff1c337996020410);
    __atomic_store_n(&wide_object, a, __ATOMIC_RELEASE);
    if (__atomic_load_n(&wide_object, __ATOMIC_ACQUIRE) != a ||
        __atomic_exchange_n(&wide_object, b, __ATOMIC_SEQ_CST) != a)
        return 21;
    wide expected = a;
    if (__atomic_compare_exchange_n(&wide_object, &expected, a, 0, __ATOMIC_SEQ_CST, __ATOMIC_ACQUIRE) ||
        expected != b || !__atomic_compare_exchange_n(&wide_object, &expected, a, 0,
                                                      __ATOMIC_SEQ_CST, __ATOMIC_ACQUIRE))
        return 22;
    if (__atomic_fetch_add(&wide_object, b, __ATOMIC_SEQ_CST) != a ||
        __atomic_fetch_sub(&wide_object, b, __ATOMIC_SEQ_CST) != a + b ||
        __atomic_fetch_and(&wide_object, b, __ATOMIC_SEQ_CST) != a ||
        __atomic_fetch_or(&wide_object, a, __ATOMIC_SEQ_CST) != (a & b) ||
        __atomic_fetch_xor(&wide_object, b, __ATOMIC_SEQ_CST) != a ||
        __atomic_fetch_nand(&wide_object, a, __ATOMIC_SEQ_CST) != (a ^ b))
        return 23;
    return __atomic_load_n(&wide_object, __ATOMIC_ACQUIRE) == ~((a ^ b) & a) ? 0 : 24;
}

int main(void)
{
    errno = EDOM;
    int result = aggregates();
    if (result)
        return result;
    result = wide_values();
    if (result)
        return result;
    if (!__atomic_is_lock_free(size_for_query, &native_word))
        return 31;
    size_for_query = 16;
    if (__atomic_is_lock_free(size_for_query, &wide_object))
        return 32;
    return errno == EDOM ? 0 : 33;
}
