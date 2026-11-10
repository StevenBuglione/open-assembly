; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: acos
; header: math.h
; prototype: double acos(double x)
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

global acos:function
extern __al_math_asin:function

section .text.acos alloc exec nowrite progbits
acos:
    mov ecx, 1
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_asin
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
