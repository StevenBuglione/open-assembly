; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: floor
; header: math.h
; prototype: double floor(double x)
; standard: C17 7.12.9.2
; deps: feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return x rounded toward negative infinity to an integral value, preserving zero sign.
; semantics: Do not raise FE_INEXACT merely for a discarded fraction.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global floor:function
extern __al_math_round:function

section .text.floor alloc exec nowrite progbits
floor:
    mov ecx, 1024
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_round
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
