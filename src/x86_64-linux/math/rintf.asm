; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: rintf
; header: math.h
; prototype: float rintf(float x)
; standard: C17 7.12.9.4
; deps: feraiseexcept, fegetround
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Round x to an integral value in the active rounding mode. Preserve zero sign.
; semantics: Raise FE_INEXACT if a nonzero fraction is discarded.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global rintf:function
extern __al_math_round:function

section .text.rintf alloc exec nowrite progbits
rintf:
    mov ecx, 4097
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_round
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
