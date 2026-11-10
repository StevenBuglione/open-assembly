; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: erff
; header: math.h
; prototype: float erff(float x)
; standard: C17 7.12.8.1
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the error function in the active rounding mode.
; semantics: Preserve signed zero and return signed one for infinity.
; semantics: Quiet signaling NaNs and raise FE_INVALID. A tiny inexact result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global erff:function
extern __al_math_erf:function

section .text.erff alloc exec nowrite progbits
erff:
    xor ecx, ecx
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_erf
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
