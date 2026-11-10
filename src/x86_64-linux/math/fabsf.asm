; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fabsf
; header: math.h
; prototype: float fabsf(float x)
; standard: C17 7.12.7.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Clear the sign of x and preserve the other value bits.
; semantics: This bit operation preserves errno and floating exception flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fabsf:function

section .text.fabsf alloc exec nowrite progbits
fabsf:
    movd eax, xmm0
    and eax, 0x7fffffff
    movd xmm0, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
