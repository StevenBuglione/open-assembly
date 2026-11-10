; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: __atomic_store
; header: compiler_rt.h
; prototype: void __atomic_store(size_t size, volatile void *object, const void *value, int order)
; standard: Runtime ABI __atomic_store
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:compiler-atomic-abi, diff:libatomic
; provenance: original
; narrow_args: ecx:s32
; variadic: false
; semantics: Atomically replace the object representation with value.
; semantics: Use sequentially consistent ordering and the baseline alignment policy.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global __atomic_store:function
extern __al_atomic_bytes:function

section .text.__atomic_store alloc exec nowrite progbits
__atomic_store:
    mov r8d, 1
    sub rsp, 8
    call __al_atomic_bytes
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
