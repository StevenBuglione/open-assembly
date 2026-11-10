; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atanf
; header: math.h
; prototype: float atanf(float x)
; standard: C17 7.12.4.3
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the inverse tangent in radians and use the active rounding mode.
; semantics: Preserve signed zero. Infinite operands produce the signed half-pi result.
; semantics: Quiet signaling NaNs and raise FE_INVALID. An inexact tiny result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atanf:function
extern __al_math_atan:function

section .text.atanf alloc exec nowrite progbits
atanf:
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_atan
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
