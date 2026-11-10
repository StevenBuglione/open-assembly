; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fmod
; header: math.h
; prototype: double fmod(double x, double y)
; standard: C17 7.12.10.1
; deps: __errno_location, feraiseexcept
; errno: EDOM
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the exact remainder with the sign of x, using a quotient truncated toward zero.
; semantics: A zero divisor or infinite dividend reports EDOM and FE_INVALID and returns a quiet NaN. A NaN operand takes precedence over those domain errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fmod:function
extern __al_math_rem:function

section .text.fmod alloc exec nowrite progbits
fmod:
    movq rcx, xmm1
    xor r8d, r8d
    mov r9d, 0
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_rem
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
