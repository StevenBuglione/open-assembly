; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: __atomic_load_16
; header: compiler_rt.h
; prototype: unsigned __int128 __atomic_load_16(const volatile void *object, int order)
; standard: Runtime ABI __atomic_load_16
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:compiler-atomic-abi, diff:libatomic
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Atomically return the 16-byte object representation.
; semantics: Use sequentially consistent ordering and the baseline alignment policy.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global __atomic_load_16:function
extern __al_atomic_quad:function

section .text.__atomic_load_16 alloc exec nowrite progbits
__atomic_load_16:
    mov ecx, 6
    sub rsp, 8
    call __al_atomic_quad
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
