; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: logb
; header: math.h
; prototype: double logb(double x)
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

global logb:function
extern __al_math_logb:function

section .text.logb alloc exec nowrite progbits
logb:
    xor ecx, ecx
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_logb
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
