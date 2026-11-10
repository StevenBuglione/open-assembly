; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cosl
; header: math.h
; prototype: long double cosl(long double x)
; standard: C17 7.12.4.5
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the cos of x in radians and use the active rounding mode.
; semantics: Return positive one for either zero. An infinite operand yields a quiet NaN with EDOM and FE_INVALID.
; semantics: Quiet NaNs propagate. A signaling NaN is quieted with FE_INVALID. An inexact tiny result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cosl:function
extern __al_math_trig:function

section .text.cosl alloc exec nowrite progbits
cosl:
    mov ecx, 1
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_trig
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
