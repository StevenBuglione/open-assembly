; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: asinf
; header: math.h
; prototype: float asinf(float x)
; standard: C17 7.12.4.2
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the asin of x in radians and use the active rounding mode.
; semantics: Preserve signed zero. Magnitudes above one report EDOM and FE_INVALID with a quiet NaN.
; semantics: Signaling NaNs are quieted with FE_INVALID. A tiny inexact result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global asinf:function
extern __al_math_asin:function

section .text.asinf alloc exec nowrite progbits
asinf:
    mov ecx, 0
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_asin
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
