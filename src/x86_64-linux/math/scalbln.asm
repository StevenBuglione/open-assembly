; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: scalbln
; header: math.h
; prototype: double scalbln(double x, long n)
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

global scalbln:function
extern __al_math_scale:function

section .text.scalbln alloc exec nowrite progbits
scalbln:
    mov rcx, rdi
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_scale
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
