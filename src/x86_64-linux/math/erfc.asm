; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: erfc
; header: math.h
; prototype: double erfc(double x)
; standard: C17 7.12.8.2
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the complementary error function in the active rounding mode.
; semantics: Return one for either zero, zero for positive infinity, and two for negative infinity.
; semantics: Quiet signaling NaNs and raise FE_INVALID. A tiny inexact result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global erfc:function
extern __al_math_erf:function

section .text.erfc alloc exec nowrite progbits
erfc:
    mov ecx, 1
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_erf
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
