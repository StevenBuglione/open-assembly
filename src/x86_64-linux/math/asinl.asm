; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: asinl
; header: math.h
; prototype: long double asinl(long double x)
; standard: C17 7.12.4.2
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the asin of x in radians and use the active rounding mode.
; semantics: Preserve signed zero. Magnitudes above one report EDOM and FE_INVALID with a quiet NaN.
; semantics: Signaling NaNs are quieted with FE_INVALID. A tiny inexact result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global asinl:function
extern __al_math_asin:function

section .text.asinl alloc exec nowrite progbits
asinl:
    mov ecx, 0
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_asin
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
