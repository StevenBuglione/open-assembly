; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: log2l
; header: math.h
; prototype: long double log2l(long double x)
; standard: C17 7.12.6.10
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the base-two logarithm of x in the active rounding mode.
; semantics: Either zero reports a pole with negative infinity, ERANGE and FE_DIVBYZERO. A negative nonzero operand reports a domain error with a quiet NaN, EDOM and FE_INVALID.
; semantics: Positive infinity stays infinity. Quiet NaNs propagate, and signaling NaNs are quieted with FE_INVALID.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global log2l:function
extern __al_math_log:function

section .text.log2l alloc exec nowrite progbits
log2l:
    mov ecx, 0
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
