; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: asinh
; header: math.h
; prototype: double asinh(double x)
; standard: C17 7.12.5.2
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the inverse hyperbolic sine in the active rounding mode. Preserve the sign of zero and infinity.
; semantics: Quiet signaling NaNs and raise FE_INVALID.
; semantics: A tiny inexact result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global asinh:function
extern __al_math_inverse_hyperbolic:function

section .text.asinh alloc exec nowrite progbits
asinh:
    mov ecx, 0
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_inverse_hyperbolic
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
