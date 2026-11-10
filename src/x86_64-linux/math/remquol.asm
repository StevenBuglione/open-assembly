; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: remquol
; header: math.h
; prototype: long double remquol(long double x, long double y, int *quo)
; standard: C17 7.12.10.3
; deps: __errno_location, feraiseexcept
; errno: EDOM
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the same remainder as remainder and store the signed low seven bits of its integral quotient through quo.
; semantics: On a NaN result store zero through quo. A zero divisor or infinite dividend reports EDOM and FE_INVALID unless an operand is NaN.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global remquol:function
extern __al_math_rem:function

section .text.remquol alloc exec nowrite progbits
remquol:
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov r9, rdi
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
