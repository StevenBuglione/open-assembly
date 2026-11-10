; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fmaf
; header: math.h
; prototype: float fmaf(float x, float y, float z)
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

global fmaf:function
extern __al_math_fma:function

section .text.fmaf alloc exec nowrite progbits
fmaf:
    movd esi, xmm0
    movd edx, xmm1
    movd ecx, xmm2
    xor r8d, r8d
    mov edi, 0
    sub rsp, 8
    call __al_math_fma
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
