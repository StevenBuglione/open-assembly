; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fabs
; header: math.h
; prototype: double fabs(double x)
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

global fabs:function

section .text.fabs alloc exec nowrite progbits
fabs:
    movq rax, xmm0
    shl rax, 1
    shr rax, 1
    movq xmm0, rax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
