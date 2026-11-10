; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: truncl
; header: math.h
; prototype: long double truncl(long double x)
; standard: C17 7.12.9.8
; deps: feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Discard the fractional part of x, preserving zero sign.
; semantics: Do not raise FE_INEXACT merely for a discarded fraction.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global truncl:function
extern __al_math_round:function

section .text.truncl alloc exec nowrite progbits
truncl:
    mov ecx, 3072
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_round
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
