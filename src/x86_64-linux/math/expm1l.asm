; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: expm1l
; header: math.h
; prototype: long double expm1l(long double x)
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

global expm1l:function
extern __al_math_exp:function

section .text.expm1l alloc exec nowrite progbits
expm1l:
    mov ecx, 2
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_exp
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
