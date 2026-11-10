; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tanh
; header: math.h
; prototype: double tanh(double x)
; standard: C17 7.12.5.6
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the hyperbolic tangent of x in the active rounding mode.
; semantics: Preserve signed zero and return signed one for infinity.
; semantics: Quiet signaling NaNs and raise FE_INVALID. Overflow or an inexact tiny result reports ERANGE with the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tanh:function
extern __al_math_hyperbolic:function

section .text.tanh alloc exec nowrite progbits
tanh:
    mov ecx, 2
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_hyperbolic
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
