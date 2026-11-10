; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: remquo
; header: math.h
; prototype: double remquo(double x, double y, int *quo)
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

global remquo:function
extern __al_math_rem:function

section .text.remquo alloc exec nowrite progbits
remquo:
    movq rcx, xmm1
    xor r8d, r8d
    mov r9, rdi
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_rem
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
