; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: remainderf
; header: math.h
; prototype: float remainderf(float x, float y)
; standard: C17 7.12.10.2
; deps: __errno_location, feraiseexcept
; errno: EDOM
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the exact remainder with a quotient rounded to nearest integer, with ties to even, independently of the active rounding mode.
; semantics: Preserve the sign of x for a zero result. A zero divisor or infinite dividend reports EDOM and FE_INVALID unless an operand is NaN.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global remainderf:function
extern __al_math_rem:function

section .text.remainderf alloc exec nowrite progbits
remainderf:
    movd ecx, xmm1
    xor r8d, r8d
    mov r9d, 1
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_rem
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
