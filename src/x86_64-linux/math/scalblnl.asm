; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: scalblnl
; header: math.h
; prototype: long double scalblnl(long double x, long n)
; standard: C17 7.12.6.13
; deps: feraiseexcept, __errno_location, fegetround
; errno: ERANGE
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Multiply x by two raised to the long exponent and round in the active mode.
; semantics: Handle large exponents without integer overflow. Overflow and tiny inexact results set ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global scalblnl:function
extern __al_math_scale:function

section .text.scalblnl alloc exec nowrite progbits
scalblnl:
    mov rcx, rdi
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_scale
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
