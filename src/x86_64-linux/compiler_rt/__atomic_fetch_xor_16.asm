; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: __atomic_fetch_xor_16
; header: compiler_rt.h
; prototype: unsigned __int128 __atomic_fetch_xor_16(volatile void *object, unsigned __int128 operand, int order)
; standard: Runtime ABI __atomic_fetch_xor_16
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:compiler-atomic-abi, diff:libatomic
; provenance: original
; narrow_args: ecx:s32
; variadic: false
; semantics: Atomically replace the 16-byte value with the bitwise XOR and return the previous value.
; semantics: Use sequentially consistent ordering and the baseline alignment policy.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global __atomic_fetch_xor_16:function
extern __al_atomic_quad:function

section .text.__atomic_fetch_xor_16 alloc exec nowrite progbits
__atomic_fetch_xor_16:
    mov ecx, 4
    sub rsp, 8
    call __al_atomic_quad
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
