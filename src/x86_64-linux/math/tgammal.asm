; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tgammal
; header: math.h
; prototype: long double tgammal(long double x)
; standard: C17 7.12.8.4
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the gamma value, including its sign on the negative real intervals. Use the active rounding mode.
; semantics: Signed zero gives signed infinity with ERANGE and FE_DIVBYZERO. Negative integers and negative infinity report EDOM and FE_INVALID with a quiet NaN.
; semantics: Quiet signaling NaNs with FE_INVALID. Overflow or a tiny inexact result reports ERANGE with the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tgammal:function
extern __al_math_gamma:function

section .text.tgammal alloc exec nowrite progbits
tgammal:
    mov ecx, 1
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_gamma
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
