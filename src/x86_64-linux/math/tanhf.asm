; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tanhf
; header: math.h
; prototype: float tanhf(float x)
; standard: C17 7.12.5.6
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the hyperbolic tangent of x in the active rounding mode.
; semantics: Preserve signed zero and return signed one for infinity.
; semantics: Quiet signaling NaNs and raise FE_INVALID. Overflow or an inexact tiny result reports ERANGE with the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tanhf:function
extern __al_math_hyperbolic:function

section .text.tanhf alloc exec nowrite progbits
tanhf:
    mov ecx, 2
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_hyperbolic
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
