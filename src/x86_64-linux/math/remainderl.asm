; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: remainderl
; header: math.h
; prototype: long double remainderl(long double x, long double y)
; standard: C17 7.12.10.2
; deps: __errno_location, feraiseexcept
; errno: EDOM
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the exact remainder with a quotient rounded to nearest integer, with ties to even, independently of the active rounding mode.
; semantics: Preserve the sign of x for a zero result. A zero divisor or infinite dividend reports EDOM and FE_INVALID unless an operand is NaN.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global remainderl:function
extern __al_math_rem:function

section .text.remainderl alloc exec nowrite progbits
remainderl:
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov r9d, 1
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_rem
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
