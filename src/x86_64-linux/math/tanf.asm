; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tanf
; header: math.h
; prototype: float tanf(float x)
; standard: C17 7.12.4.7
; deps: fegetround, feraiseexcept, __errno_location
; errno: EDOM, ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the tangent of x in radians and use the active rounding mode.
; semantics: Preserve the sign of a zero input. An infinite operand yields a quiet NaN with EDOM and FE_INVALID.
; semantics: Quiet NaNs propagate. A signaling NaN is quieted with FE_INVALID. Overflow or a tiny inexact result reports ERANGE with the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tanf:function
extern __al_math_trig:function

section .text.tanf alloc exec nowrite progbits
tanf:
    mov ecx, 2
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_trig
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
