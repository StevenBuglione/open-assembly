; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fmal
; header: math.h
; prototype: long double fmal(long double x, long double y, long double z)
; standard: C17 7.12.13.1
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:exact-rational, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Evaluate x times y plus z exactly and round once to the return type in the active mode.
; semantics: When no NaN argument takes precedence, an infinite operand times zero or opposite infinite summands report EDOM and FE_INVALID.
; semantics: Report ERANGE for overflow or an inexact tiny result. An exact cancellation is negative zero only under downward rounding.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fmal:function
extern __al_math_fma:function

section .text.fmal alloc exec nowrite progbits
fmal:
    mov rsi, [rsp + 8]
    mov rdx, [rsp + 24]
    mov rcx, [rsp + 40]
    movzx r8d, word [rsp + 48]
    shl r8, 16
    movzx eax, word [rsp + 32]
    or r8, rax
    shl r8, 16
    movzx eax, word [rsp + 16]
    or r8, rax
    mov edi, 2
    sub rsp, 24
    call __al_math_fma
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
