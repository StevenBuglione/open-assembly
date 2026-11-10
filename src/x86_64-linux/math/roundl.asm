; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: roundl
; header: math.h
; prototype: long double roundl(long double x)
; standard: C17 7.12.9.6
; deps: feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Round to nearest integral value with ties away from zero, independently of the active mode.
; semantics: Preserve zero sign. Do not raise FE_INEXACT merely for a discarded fraction.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global roundl:function
extern __al_math_round:function

section .text.roundl alloc exec nowrite progbits
roundl:
    mov ecx, 4096
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
