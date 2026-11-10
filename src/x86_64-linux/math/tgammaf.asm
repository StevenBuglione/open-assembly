; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tgammaf
; header: math.h
; prototype: float tgammaf(float x)
; standard: C17 7.12.8.4
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the gamma value, including its sign on the negative real intervals. Use the active rounding mode.
; semantics: Signed zero gives signed infinity with ERANGE and FE_DIVBYZERO. Negative integers and negative infinity report EDOM and FE_INVALID with a quiet NaN.
; semantics: Quiet signaling NaNs with FE_INVALID. Overflow or a tiny inexact result reports ERANGE with the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tgammaf:function
extern __al_math_gamma:function

section .text.tgammaf alloc exec nowrite progbits
tgammaf:
    mov ecx, 1
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_gamma
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
