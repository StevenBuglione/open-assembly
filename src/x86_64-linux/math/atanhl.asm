; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atanhl
; header: math.h
; prototype: long double atanhl(long double x)
; standard: C17 7.12.5.3
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the inverse hyperbolic tangent in the active rounding mode. Magnitudes above one yield a quiet NaN with EDOM and FE_INVALID. At magnitude one return signed infinity with ERANGE and FE_DIVBYZERO.
; semantics: Quiet signaling NaNs and raise FE_INVALID.
; semantics: A tiny inexact result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atanhl:function
extern __al_math_inverse_hyperbolic:function

section .text.atanhl alloc exec nowrite progbits
atanhl:
    mov ecx, 2
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
