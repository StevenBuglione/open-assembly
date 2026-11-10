; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cosh
; header: math.h
; prototype: double cosh(double x)
; standard: C17 7.12.5.4
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the hyperbolic cosine of x in the active rounding mode.
; semantics: Return one for either zero and positive infinity for either infinity.
; semantics: Quiet signaling NaNs and raise FE_INVALID. Overflow or an inexact tiny result reports ERANGE with the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cosh:function
extern __al_math_hyperbolic:function

section .text.cosh alloc exec nowrite progbits
cosh:
    mov ecx, 1
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_hyperbolic
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
