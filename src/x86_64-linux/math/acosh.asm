; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: acosh
; header: math.h
; prototype: double acosh(double x)
; standard: C17 7.12.5.1
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the inverse hyperbolic cosine in the active rounding mode. Inputs below one yield a quiet NaN with EDOM and FE_INVALID.
; semantics: Quiet signaling NaNs and raise FE_INVALID.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global acosh:function
extern __al_math_inverse_hyperbolic:function

section .text.acosh alloc exec nowrite progbits
acosh:
    mov ecx, 1
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_inverse_hyperbolic
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
