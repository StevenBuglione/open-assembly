; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: frexpf
; header: math.h
; prototype: float frexpf(float x, int *exp)
; standard: C17 7.12.6.4
; deps: feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Decompose finite nonzero x into a signed fraction of magnitude in [0.5, 1) and an integer power of two.
; semantics: Store exponent zero for zero, infinity or NaN. Preserve the sign of zero.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global frexpf:function
extern __al_math_frexp:function

section .text.frexpf alloc exec nowrite progbits
frexpf:
    mov rcx, rdi
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_frexp
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
