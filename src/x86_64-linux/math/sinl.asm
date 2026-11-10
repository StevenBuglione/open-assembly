; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sinl
; header: math.h
; prototype: long double sinl(long double x)
; standard: C17 7.12.4.6
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the sin of x in radians and use the active rounding mode.
; semantics: Preserve the sign of a zero input. An infinite operand yields a quiet NaN with EDOM and FE_INVALID.
; semantics: Quiet NaNs propagate. A signaling NaN is quieted with FE_INVALID. An inexact tiny result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sinl:function
extern __al_math_trig:function

section .text.sinl alloc exec nowrite progbits
sinl:
    mov ecx, 0
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
