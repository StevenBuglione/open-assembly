; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: roundf
; header: math.h
; prototype: float roundf(float x)
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

global roundf:function
extern __al_math_round:function

section .text.roundf alloc exec nowrite progbits
roundf:
    mov ecx, 4096
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_round
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
