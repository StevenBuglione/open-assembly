; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atan2f
; header: math.h
; prototype: float atan2f(float y, float x)
; standard: C17 7.12.4.4
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the inverse tangent in radians and use the active rounding mode.
; semantics: Use both signs to select the quadrant, including for signed zeros and infinities.
; semantics: Quiet signaling NaNs and raise FE_INVALID. An inexact tiny result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atan2f:function
extern __al_math_atan:function

section .text.atan2f alloc exec nowrite progbits
atan2f:
    movd ecx, xmm1
    xor r8d, r8d
    mov r9d, 1
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_atan
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
