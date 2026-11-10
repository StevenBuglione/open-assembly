; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fma
; header: math.h
; prototype: double fma(double x, double y, double z)
; standard: C17 7.12.13.1
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:exact-rational, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Evaluate x times y plus z exactly and round once to the return type in the active mode.
; semantics: When no NaN argument takes precedence, an infinite operand times zero or opposite infinite summands report EDOM and FE_INVALID.
; semantics: Report ERANGE for overflow or an inexact tiny result. An exact cancellation is negative zero only under downward rounding.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fma:function
extern __al_math_fma:function

section .text.fma alloc exec nowrite progbits
fma:
    movq rsi, xmm0
    movq rdx, xmm1
    movq rcx, xmm2
    xor r8d, r8d
    mov edi, 1
    sub rsp, 8
    call __al_math_fma
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
