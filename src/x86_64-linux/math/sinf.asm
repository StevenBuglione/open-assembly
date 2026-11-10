; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sinf
; header: math.h
; prototype: float sinf(float x)
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

global sinf:function
extern __al_math_trig:function

section .text.sinf alloc exec nowrite progbits
sinf:
    mov ecx, 0
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_trig
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
