; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: acoshf
; header: math.h
; prototype: float acoshf(float x)
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

global acoshf:function
extern __al_math_inverse_hyperbolic:function

section .text.acoshf alloc exec nowrite progbits
acoshf:
    mov ecx, 1
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_inverse_hyperbolic
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
