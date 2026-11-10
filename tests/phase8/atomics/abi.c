#include <compiler_rt.h>
#include <errno.h>
#include <stdint.h>

extern unsigned phase2_abi_probe(uintptr_t, const uint64_t[6]);
#define ADDR(pointer) ((uint64_t)(uintptr_t)(pointer))
#define ORDER(value) (UINT64_C(0x72032d1100000000) | (uint32_t)(value))
#define CALL(function, ...) do { \
    errno = EDOM; \
    if (phase2_abi_probe((uintptr_t)function, (const uint64_t[6]){__VA_ARGS__}) || errno != EDOM) \
        return step; \
    ++step; \
} while (0)

int main(void)
{
    _Alignas(16) unsigned __int128 object = 123, source = 47, output = 19;
    const uint64_t pointer = ADDR(&object), input = ADDR(&source), result = ADDR(&output);
    const uint64_t seq = ORDER(__ATOMIC_SEQ_CST), acquire = ORDER(__ATOMIC_ACQUIRE);
    const uint64_t lo = UINT64_C(0xa5072d13010e0348), hi = UINT64_C(0x21249613789adecf);
    int step = 10;
    CALL(__al_abi_atomic_load, 16, pointer, result, acquire);
    CALL(__al_abi_atomic_store, 16, pointer, input, seq);
    CALL(__al_abi_atomic_exchange, 16, pointer, input, result, seq);
    CALL(__al_abi_atomic_compare_exchange, 16, pointer, result, input, seq, acquire);
    CALL(__al_abi_atomic_is_lock_free, 8, pointer);
    CALL(__al_abi_atomic_load_16, pointer, acquire);
    CALL(__al_abi_atomic_store_16, pointer, lo, hi, seq);
    CALL(__al_abi_atomic_exchange_16, pointer, lo, hi, seq);
    CALL(__al_abi_atomic_compare_exchange_16, pointer, result, lo, hi, seq, acquire);
    CALL(__al_abi_atomic_fetch_add_16, pointer, lo, hi, seq);
    CALL(__al_abi_atomic_fetch_sub_16, pointer, lo, hi, seq);
    CALL(__al_abi_atomic_fetch_and_16, pointer, lo, hi, seq);
    CALL(__al_abi_atomic_fetch_or_16, pointer, lo, hi, seq);
    CALL(__al_abi_atomic_fetch_xor_16, pointer, lo, hi, seq);
    CALL(__al_abi_atomic_fetch_nand_16, pointer, lo, hi, seq);
    return 0;
}
