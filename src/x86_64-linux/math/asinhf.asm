; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: asinhf
; header: math.h
; prototype: float asinhf(float x)
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

global asinhf:function
extern __al_math_inverse_hyperbolic:function

section .text.asinhf alloc exec nowrite progbits
asinhf:
    mov ecx, 0
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_inverse_hyperbolic
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
