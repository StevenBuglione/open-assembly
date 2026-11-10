# Phase 3 allocator and environment oracles

These freestanding fixtures use the shipped startup and runtime archive.
The gate checks the undefined references in the test objects, the final
symbol definitions, the ELF layout, and reproducibility across two builds.

| Oracle | Expected observations |
| --- | --- |
| `reference:phase3-contract` | The allocator preserves `errno` on success, returns a freeable aligned pointer for successful zero-size requests, checks size arithmetic, and leaves the old allocation intact when a resize fails. Environment initialization preserves the original stack vectors. Mutations honor the contract for aliasing, invalid arguments, and caller-owned storage. [Allocator and environment ABI](../../docs/adr/0004-allocator-environment.md) |
| `c17:allocator` | C17 §7.22.3. Test allocation and release, zeroed bytes after reuse, preserved prefixes after shrink and growth, and the minimum object alignment. [WG14 C17 baseline with later edits marked](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf) |
| `posix:alignment` | `posix_memalign` validates power-of-two pointer alignment and returns errors directly, leaving the output pointer and `errno` unchanged on failure. [POSIX posix_memalign](https://pubs.opengroup.org/onlinepubs/9799919799/functions/posix_memalign.html) |
| `reference:live-object-model` | A seeded 6,144-operation model tracks up to 64 live allocations. It checks disjoint ranges, alignment, zero fill, retained contents, failure preservation, and cleanup. The separate slab churn case holds 3,400 tiny allocations, frees alternating slots, refills them with `calloc`, and checks every live byte before release. |
| `posix:environment` | Lookup matches complete names and returns borrowed values. `setenv` copies, `putenv` borrows mutable strings, and `unsetenv` removes duplicate names while preserving neighboring entries and the terminator. A 4,096-operation model checks values and the active entry count after every mutation. [POSIX setenv](https://pubs.opengroup.org/onlinepubs/9799919799/functions/setenv.html), [POSIX putenv](https://pubs.opengroup.org/onlinepubs/9799919799/functions/putenv.html) |
| `abi:sysv-amd64` | The native trampoline exercises all ten public functions and checks the preserved CPU state. The environment startup fixture compares the initial vector addresses and auxv adjacency with the addresses received by `main`. [AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI) |
| `linux:mmap-fault-control` | The test-only wrapper of the private syscall boundary denies one selected anonymous read/write mapping with raw `-ENOMEM`. The fixture asserts caller-visible failure, preserved contents or environment state, and the exact count of selected injected, real mapped and matching unmapped requests. [Linux mmap UAPI](https://github.com/torvalds/linux/blob/master/include/uapi/asm-generic/mman-common.h) |

The allocator and environment model seeds are `0xa3110c31` and
`0x65a11ea3`. Normal cases are linked without fault injection. A fault
fixture arms its wrapper after startup and filters by syscall, flags,
protection and request length. Requests outside the filter go to the real
runtime boundary. The release and environment churn cases only observe
mappings. They respectively require one matching release and 48 matching
releases. The gate records the observed counts and the actual linker
wrapper and runtime definitions.

The generated-stub controls assert a distinct, exact failure status for
each public function. The `free` control requires a matching real
`munmap`, so a stub that returns without releasing the allocation fails
without relying on address reuse or invalid access to a freed object.

The model checks live object ranges and written bytes because Memcheck
sees the underlying slab mapping as addressable. The CPU state probe runs
natively. The remaining cases run natively, under QEMU, and under
Valgrind. The fixtures cover the initial single-threaded runtime.

```sh
./tools/container python3 tools/phase3.py
```
