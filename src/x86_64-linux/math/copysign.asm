; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: copysign
; header: math.h
; prototype: double copysign(double x, double y)
; standard: C17 7.12.11.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the magnitude of x with the sign bit of y.
; semantics: Preserve errno and floating exception flags, including for NaN inputs.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global copysign:function

section .text.copysign alloc exec nowrite progbits
copysign:
    movq rax, xmm0
    movq rdx, xmm1
    shl rax, 1
    shr rax, 1
    shr rdx, 63
    shl rdx, 63
    or rax, rdx
    movq xmm0, rax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
