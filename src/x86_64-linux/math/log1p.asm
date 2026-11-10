; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: log1p
; header: math.h
; prototype: double log1p(double x)
; standard: C17 7.12.6.9
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the natural logarithm of one plus x in the active rounding mode, retaining the correction near zero.
; semantics: Preserve signed zero. At minus one return negative infinity with ERANGE and FE_DIVBYZERO. Below minus one return a quiet NaN with EDOM and FE_INVALID.
; semantics: Positive infinity stays infinity. Signaling NaNs are quieted with FE_INVALID. An inexact tiny result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global log1p:function
extern __al_math_log:function

section .text.log1p alloc exec nowrite progbits
log1p:
    mov ecx, 3
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_log
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
