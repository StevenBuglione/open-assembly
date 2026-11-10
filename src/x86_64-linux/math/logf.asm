; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: logf
; header: math.h
; prototype: float logf(float x)
; standard: C17 7.12.6.7
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the natural logarithm of x in the active rounding mode.
; semantics: Either zero reports a pole with negative infinity, ERANGE and FE_DIVBYZERO. A negative nonzero operand reports a domain error with a quiet NaN, EDOM and FE_INVALID.
; semantics: Positive infinity stays infinity. Quiet NaNs propagate, and signaling NaNs are quieted with FE_INVALID.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global logf:function
extern __al_math_log:function

section .text.logf alloc exec nowrite progbits
logf:
    mov ecx, 1
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_log
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
