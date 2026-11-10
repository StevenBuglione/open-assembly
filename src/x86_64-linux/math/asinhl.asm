; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: asinhl
; header: math.h
; prototype: long double asinhl(long double x)
; standard: C17 7.12.5.2
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the inverse hyperbolic sine in the active rounding mode. Preserve the sign of zero and infinity.
; semantics: Quiet signaling NaNs and raise FE_INVALID.
; semantics: A tiny inexact result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global asinhl:function
extern __al_math_inverse_hyperbolic:function

section .text.asinhl alloc exec nowrite progbits
asinhl:
    mov ecx, 0
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_inverse_hyperbolic
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
