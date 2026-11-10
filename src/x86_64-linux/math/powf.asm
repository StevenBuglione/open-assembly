; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: powf
; header: math.h
; prototype: float powf(float x, float y)
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

global powf:function
extern __al_math_pow:function

section .text.powf alloc exec nowrite progbits
powf:
    movd ecx, xmm1
    xor r8d, r8d
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_pow
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
