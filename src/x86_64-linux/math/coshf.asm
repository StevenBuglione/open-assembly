; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: coshf
; header: math.h
; prototype: float coshf(float x)
; standard: C17 7.12.5.4
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the hyperbolic cosine of x in the active rounding mode.
; semantics: Return one for either zero and positive infinity for either infinity.
; semantics: Quiet signaling NaNs and raise FE_INVALID. Overflow or an inexact tiny result reports ERANGE with the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global coshf:function
extern __al_math_hyperbolic:function

section .text.coshf alloc exec nowrite progbits
coshf:
    mov ecx, 1
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_hyperbolic
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
