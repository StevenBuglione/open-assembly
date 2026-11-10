; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: rintl
; header: math.h
; prototype: long double rintl(long double x)
; standard: C17 7.12.9.4
; deps: feraiseexcept, fegetround
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Round x to an integral value in the active rounding mode. Preserve zero sign.
; semantics: Raise FE_INEXACT if a nonzero fraction is discarded.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global rintl:function
extern __al_math_round:function

section .text.rintl alloc exec nowrite progbits
rintl:
    mov ecx, 4097
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
