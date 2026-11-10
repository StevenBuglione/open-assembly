; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atanh
; header: math.h
; prototype: double atanh(double x)
; standard: C17 7.12.5.3
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the inverse hyperbolic tangent in the active rounding mode. Magnitudes above one yield a quiet NaN with EDOM and FE_INVALID. At magnitude one return signed infinity with ERANGE and FE_DIVBYZERO.
; semantics: Quiet signaling NaNs and raise FE_INVALID.
; semantics: A tiny inexact result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atanh:function
extern __al_math_inverse_hyperbolic:function

section .text.atanh alloc exec nowrite progbits
atanh:
    mov ecx, 2
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_inverse_hyperbolic
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
