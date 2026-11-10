; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: expm1
; header: math.h
; prototype: double expm1(double x)
; standard: C17 7.12.6.4
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute e raised to x minus one in the active rounding mode.
; semantics: Preserve the sign of a zero input. Return negative one for negative infinity and positive infinity for positive infinity.
; semantics: Quiet signaling NaNs and raise FE_INVALID. Overflow or an inexact tiny result reports ERANGE with the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global expm1:function
extern __al_math_exp:function

section .text.expm1 alloc exec nowrite progbits
expm1:
    mov ecx, 2
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_exp
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
