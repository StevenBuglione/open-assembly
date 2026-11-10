; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: acosf
; header: math.h
; prototype: float acosf(float x)
; standard: C17 7.12.4.1
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the acos of x in radians and use the active rounding mode.
; semantics: For positive one return positive zero. Either zero returns half pi. Magnitudes above one report EDOM and FE_INVALID with a quiet NaN.
; semantics: Signaling NaNs are quieted with FE_INVALID. A tiny inexact result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global acosf:function
extern __al_math_asin:function

section .text.acosf alloc exec nowrite progbits
acosf:
    mov ecx, 1
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_asin
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
