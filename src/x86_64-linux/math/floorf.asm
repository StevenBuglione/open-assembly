; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: floorf
; header: math.h
; prototype: float floorf(float x)
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

global floorf:function
extern __al_math_round:function

section .text.floorf alloc exec nowrite progbits
floorf:
    mov ecx, 1024
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_round
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
