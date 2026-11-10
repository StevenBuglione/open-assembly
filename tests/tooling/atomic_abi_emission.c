#include <stdbool.h>
#include <stdatomic.h>
#include <stddef.h>
#include <stdint.h>

#define ATOMIC_CALLS(tag, type) \
type load##tag(_Atomic(type) *p) { return atomic_load_explicit(p, memory_order_acquire); } \
void store##tag(_Atomic(type) *p, type a) { atomic_store_explicit(p, a, memory_order_release); } \
type exchange##tag(_Atomic(type) *p, type a) { return atomic_exchange_explicit(p, a, memory_order_seq_cst); } \
bool compare##tag(_Atomic(type) *p, type *e, type d) \
{ return atomic_compare_exchange_weak_explicit(p, e, d, memory_order_acq_rel, memory_order_acquire); } \
bool free##tag(_Atomic(type) *p) { return atomic_is_lock_free(p); }
ATOMIC_CALLS(1, uint8_t)
ATOMIC_CALLS(2, uint16_t)
ATOMIC_CALLS(4, uint32_t)
ATOMIC_CALLS(8, uint64_t)
#ifndef LOCK_FREE_ONLY
typedef unsigned __int128 u128;
ATOMIC_CALLS(16, u128)
struct three_bytes { unsigned char a[3]; };
struct twenty_four { unsigned char a[24]; };
ATOMIC_CALLS(3, struct three_bytes)
ATOMIC_CALLS(24, struct twenty_four)

#define RMW(op) \
u128 fetch_##op##16(u128 *p, u128 x) { return __atomic_fetch_##op(p, x, __ATOMIC_SEQ_CST); } \
u128 op##_fetch16(u128 *p, u128 x) { return __atomic_##op##_fetch(p, x, __ATOMIC_SEQ_CST); }
RMW(add)
RMW(sub)
RMW(and)
RMW(or)
RMW(xor)
RMW(nand)

bool lock_free_runtime(size_t n, const volatile void *p) { return __atomic_is_lock_free(n, p); }
#endif
