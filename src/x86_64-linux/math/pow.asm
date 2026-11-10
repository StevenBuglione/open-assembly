; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pow
; header: math.h
; prototype: double pow(double x, double y)
; standard: C17 7.12.7.4
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute x raised to y. Respect the sign rules for odd integral exponents and the active rounding mode.
; semantics: A finite negative nonzero base and finite nonintegral exponent report EDOM and FE_INVALID. A finite negative exponent with a zero base reports ERANGE and FE_DIVBYZERO.
; semantics: Overflow or an inexact tiny result reports ERANGE with the corresponding flags. Signaling NaNs take precedence and are quieted with FE_INVALID.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pow:function
extern __al_math_pow:function

section .text.pow alloc exec nowrite progbits
pow:
    movq rcx, xmm1
    xor r8d, r8d
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_pow
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
