; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: __atomic_load
; header: compiler_rt.h
; prototype: void __atomic_load(size_t size, const volatile void *object, void *result, int order)
; standard: Runtime ABI __atomic_load
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:compiler-atomic-abi, diff:libatomic
; provenance: original
; narrow_args: ecx:s32
; variadic: false
; semantics: Atomically copy the object representation to result.
; semantics: Use sequentially consistent ordering and the baseline alignment policy.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global __atomic_load:function
extern __al_atomic_bytes:function

section .text.__atomic_load alloc exec nowrite progbits
__atomic_load:
    mov rcx, rdx
    xor r8d, r8d
    sub rsp, 8
    call __al_atomic_bytes
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
