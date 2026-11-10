; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: trunc
; header: math.h
; prototype: double trunc(double x)
; standard: C17 7.12.9.8
; deps: feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Discard the fractional part of x, preserving zero sign.
; semantics: Do not raise FE_INEXACT merely for a discarded fraction.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global trunc:function
extern __al_math_round:function

section .text.trunc alloc exec nowrite progbits
trunc:
    mov ecx, 3072
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_round
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
