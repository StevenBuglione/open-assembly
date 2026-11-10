; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: modf
; header: math.h
; prototype: double modf(double x, double *iptr)
; standard: C17 7.12.6.12
; deps: feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Store the integral part through iptr and return the fractional part. Preserve both signs, including zero.
; semantics: Infinity has a signed zero fractional part. NaN propagates to both results.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global modf:function
extern __al_math_modf:function

section .text.modf alloc exec nowrite progbits
modf:
    mov rcx, rdi
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_modf
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
