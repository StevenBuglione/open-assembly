; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: acoshl
; header: math.h
; prototype: long double acoshl(long double x)
; standard: C17 7.12.5.1
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the inverse hyperbolic cosine in the active rounding mode. Inputs below one yield a quiet NaN with EDOM and FE_INVALID.
; semantics: Quiet signaling NaNs and raise FE_INVALID.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global acoshl:function
extern __al_math_inverse_hyperbolic:function

section .text.acoshl alloc exec nowrite progbits
acoshl:
    mov ecx, 1
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
