; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ceil
; header: math.h
; prototype: double ceil(double x)
; standard: C17 7.12.9.1
; deps: feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return x rounded toward positive infinity to an integral value, preserving zero sign.
; semantics: Do not raise FE_INEXACT merely for a discarded fraction.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ceil:function
extern __al_math_round:function

section .text.ceil alloc exec nowrite progbits
ceil:
    mov ecx, 2048
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_round
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
