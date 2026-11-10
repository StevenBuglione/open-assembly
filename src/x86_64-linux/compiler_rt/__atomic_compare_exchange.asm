; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: __atomic_compare_exchange
; header: compiler_rt.h
; prototype: _Bool __atomic_compare_exchange(size_t size, volatile void *object, void *expected, const void *desired, int success_order, int failure_order)
; standard: Runtime ABI __atomic_compare_exchange
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:compiler-atomic-abi, diff:libatomic
; provenance: original
; narrow_args: r8d:s32, r9d:s32
; variadic: false
; semantics: Atomically replace matching bytes. On mismatch, publish the observed bytes to expected.
; semantics: Use sequentially consistent ordering and the baseline alignment policy.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global __atomic_compare_exchange:function
extern __al_atomic_bytes:function

section .text.__atomic_compare_exchange alloc exec nowrite progbits
__atomic_compare_exchange:
    mov r8d, 3
    sub rsp, 8
    call __al_atomic_bytes
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
