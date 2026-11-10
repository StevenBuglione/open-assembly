; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: catanh
; header: complex.h
; prototype: double _Complex catanh(double _Complex z)
; standard: C17 7.3.6.3
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:complex-branch-cut, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the complex arc hyperbolic tangent on the principal branch, preserving the input side of the branch cut and the floating control state.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global catanh:function
extern __al_complex_inverse_tangent:function

section .text.catanh alloc exec nowrite progbits
catanh:
    movq rsi, xmm0
    movq rcx, xmm1
    xor edx, edx
    xor r8d, r8d
    mov edi, 1
    mov r9d, 0
    sub rsp, 8
    call __al_complex_inverse_tangent
    movq xmm0, rax
    movq xmm1, rcx
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
