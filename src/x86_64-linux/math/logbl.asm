; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: logbl
; header: math.h
; prototype: long double logbl(long double x)
; standard: C17 7.12.6.11
; deps: feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the base-two exponent of the leading bit as a floating value for finite nonzero x.
; semantics: For zero return negative infinity and set ERANGE with FE_DIVBYZERO. For infinity return positive infinity.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global logbl:function
extern __al_math_logb:function

section .text.logbl alloc exec nowrite progbits
logbl:
    xor ecx, ecx
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_logb
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
