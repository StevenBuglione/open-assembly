# Independent compiler atomic libcall checks

Run `./tools/container make phase8-compiler-atomics`. Direct fixtures
cover exact object representations, guard edges, both overlap directions,
unreadable zero-size buffers and lock-free queries, unsigned 128-bit
carry and borrow, and preserved errno. A separate SysV trampoline calls
all fifteen entries with poisoned upper bits in narrow ABI arguments.
The direct generated stub for each public entry has an independent
observable failure.

A four-thread case races baseline inline 8-byte operations with generic
8-byte CAS and combines generic 16-byte CAS with the typed fetch helper.
It checks exact final counters after carry and independent thread errno.
The scope is process-local and uses neither inline CMPXCHG16B nor a
cross-process locking claim.

The same independent compiler fixture builds with pinned GCC and Clang for
baseline x86-64. The 3-byte object uses GNU generic builtins, which emit
exact-size libcalls on both compilers. The 24-byte object uses C17
`stdatomic.h`, and the typed 16-byte cases use GNU builtins. Each relocatable object must actually reference
all fifteen atomic symbols. The static link map must resolve every one
to its audited assembly runtime member. Native, QEMU and strict Memcheck
run both compiler-built candidates. Clang retains its atomic alignment
and size diagnostics as warnings for these intentionally non-lock-free
inputs.

[GCC atomic builtins](https://gcc.gnu.org/onlinedocs/gcc/_005f_005fatomic-Builtins.html)
[LLVM atomic libcalls](https://llvm.org/docs/Atomics.html#libcalls-atomic)
