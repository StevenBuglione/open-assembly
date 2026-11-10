# 0037 Baseline compiler atomic libcalls

This contract covers statically linked x86-64 System V programs built with
pinned GCC 16.2.0 and Clang 21.1.8 for `-march=x86-64 -mno-cx16`. It covers
compiler-generated calls for the generic C17 atomic operations. The named
C17 flag and fence functions retain their separate contract.

The four generic entries take a byte size in the first integer register.
They load, store, exchange, or compare and exchange the exact object
representation. The compare function is strong and writes the observed
representation to `expected` only on failure. Each data buffer spans the
supplied size and is distinct from the atomic object. Exchange supports
input and output buffers that coincide or overlap. Size zero touches no
object or buffer and compares equal. The lock-free query never dereferences
its pointer. A null query pointer asks about a naturally aligned object.

The naturally aligned 1-, 2-, 4-, and 8-byte cases are lock-free and
interoperate with the baseline compiler's inline atomics at those widths.
The load uses the ordinary naturally aligned x86 load. Stores and exchanges
use the locked effect of memory `xchg`, and compare exchange uses locked
`cmpxchg`. All order arguments receive sequentially consistent behavior.
The lock-free query returns false for every other size or alignment.

The other generic cases and the 16-byte entries share a process-local
runtime lock. Their object transactions are serialized with each other.
The locking paths can block and are scoped to threads in one process.
Use only the lock-free cases in signal handlers or in mappings shared
across processes. Code compiled to inline 16-byte atomics is outside this
baseline ABI. Each `_16` load and exchange returns the previous value in
`RDX:RAX`. For `_16` compare exchange the expected pointer is in `RSI`,
the desired value is in `RCX:RDX`, and the success and failure orders are
in `R8D` and `R9D`. There is no separate weak argument at this ABI boundary.

The pinned compilers emitted these unresolved symbols for `stdatomic.h`
operations on 3-, 16-, and 24-byte objects, dynamic lock-free queries,
and 16-byte GNU arithmetic and bitwise builtins:

- `__atomic_load`, `__atomic_store`, `__atomic_exchange`,
  `__atomic_compare_exchange`, and `__atomic_is_lock_free`
- `__atomic_load_16`, `__atomic_store_16`, `__atomic_exchange_16`,
  and `__atomic_compare_exchange_16`
- `__atomic_fetch_add_16`, `__atomic_fetch_sub_16`,
  `__atomic_fetch_and_16`, `__atomic_fetch_or_16`,
  `__atomic_fetch_xor_16`, and `__atomic_fetch_nand_16`

Both compilers inline naturally aligned operations of sizes 1 through 8
at the supported power-of-two widths. Their 16-byte `op_fetch` builtins
use the same `fetch_op` helpers and compute the returned new value in the
caller. The fetch helpers return the old value and replace it with the
specified modulo-2^128 arithmetic or bitwise result. The emitted calls
and direct ABI tests are separate checks. The generated `<compiler_rt.h>`
exposes the `__al_abi_atomic_*` names for direct test calls to the real ELF
symbols without colliding with compiler builtin declarations. The runtime
preserves `errno`.

[GCC atomic builtins](https://gcc.gnu.org/onlinedocs/gcc/_005f_005fatomic-Builtins.html) ·
[GCC libatomic ABI draft](https://gcc.gnu.org/pipermail/gcc/2016-November/222252.html) ·
[LLVM Atomic Instructions and Concurrency Guide](https://llvm.org/docs/Atomics.html#libcalls-atomic)
