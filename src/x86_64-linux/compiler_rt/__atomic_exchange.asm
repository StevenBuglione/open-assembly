; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: __atomic_exchange
; header: compiler_rt.h
; prototype: void __atomic_exchange(size_t size, volatile void *object, const void *value, void *result, int order)
; standard: Runtime ABI __atomic_exchange
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:compiler-atomic-abi, diff:libatomic
; provenance: original
; narrow_args: r8d:s32
; variadic: false
; semantics: Atomically replace the object representation and copy the previous value to result.
; semantics: Use sequentially consistent ordering and the baseline alignment policy.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global __atomic_exchange:function
extern __al_atomic_bytes:function

section .text.__atomic_exchange alloc exec nowrite progbits
__atomic_exchange:
    mov r8d, 2
    sub rsp, 8
    call __al_atomic_bytes
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
