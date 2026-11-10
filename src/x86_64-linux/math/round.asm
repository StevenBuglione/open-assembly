; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: round
; header: math.h
; prototype: double round(double x)
; standard: C17 7.12.9.6
; deps: feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Round to nearest integral value with ties away from zero, independently of the active mode.
; semantics: Preserve zero sign. Do not raise FE_INEXACT merely for a discarded fraction.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global round:function
extern __al_math_round:function

section .text.round alloc exec nowrite progbits
round:
    mov ecx, 4096
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_round
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
