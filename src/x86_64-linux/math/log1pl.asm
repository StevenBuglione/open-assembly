; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: log1pl
; header: math.h
; prototype: long double log1pl(long double x)
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

global log1pl:function
extern __al_math_log:function

section .text.log1pl alloc exec nowrite progbits
log1pl:
    mov ecx, 3
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_log
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
