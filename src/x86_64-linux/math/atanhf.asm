; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atanhf
; header: math.h
; prototype: float atanhf(float x)
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

global atanhf:function
extern __al_math_inverse_hyperbolic:function

section .text.atanhf alloc exec nowrite progbits
atanhf:
    mov ecx, 2
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_inverse_hyperbolic
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
