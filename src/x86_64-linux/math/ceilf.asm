; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ceilf
; header: math.h
; prototype: float ceilf(float x)
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

global ceilf:function
extern __al_math_round:function

section .text.ceilf alloc exec nowrite progbits
ceilf:
    mov ecx, 2048
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_round
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
