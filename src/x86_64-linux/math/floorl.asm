; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: floorl
; header: math.h
; prototype: long double floorl(long double x)
; standard: C17 7.12.9.2
; deps: feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return x rounded toward negative infinity to an integral value, preserving zero sign.
; semantics: Do not raise FE_INEXACT merely for a discarded fraction.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global floorl:function
extern __al_math_round:function

section .text.floorl alloc exec nowrite progbits
floorl:
    mov ecx, 1024
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
