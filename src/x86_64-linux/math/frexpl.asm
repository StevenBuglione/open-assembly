; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: frexpl
; header: math.h
; prototype: long double frexpl(long double x, int *exp)
; standard: C17 7.12.6.4
; deps: feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Decompose finite nonzero x into a signed fraction of magnitude in [0.5, 1) and an integer power of two.
; semantics: Store exponent zero for zero, infinity or NaN. Preserve the sign of zero.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global frexpl:function
extern __al_math_frexp:function

section .text.frexpl alloc exec nowrite progbits
frexpl:
    mov rcx, rdi
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_frexp
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
