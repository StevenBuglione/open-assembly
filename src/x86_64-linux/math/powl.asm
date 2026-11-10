; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: powl
; header: math.h
; prototype: long double powl(long double x, long double y)
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

global powl:function
extern __al_math_pow:function

section .text.powl alloc exec nowrite progbits
powl:
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_pow
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
