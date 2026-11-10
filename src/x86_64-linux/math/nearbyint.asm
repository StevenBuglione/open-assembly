; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: nearbyint
; header: math.h
; prototype: double nearbyint(double x)
; standard: C17 7.12.9.3
; deps: feraiseexcept, fegetround
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Round x to an integral value in the active rounding mode. Preserve zero sign.
; semantics: Do not raise FE_INEXACT merely for a discarded fraction.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global nearbyint:function
extern __al_math_round:function

section .text.nearbyint alloc exec nowrite progbits
nearbyint:
    mov ecx, 4098
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_round
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
