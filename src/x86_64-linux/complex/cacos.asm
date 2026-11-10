; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cacos
; header: complex.h
; prototype: double _Complex cacos(double _Complex z)
; standard: C17 7.3.5.1
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:complex-branch-cut, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the complex arc cosine on the principal branch, preserving the input side of the branch cut and the floating control state.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cacos:function
extern __al_complex_inverse_circle:function

section .text.cacos alloc exec nowrite progbits
cacos:
    movq rsi, xmm0
    movq rcx, xmm1
    xor edx, edx
    xor r8d, r8d
    mov edi, 1
    mov r9d, 1
    sub rsp, 8
    call __al_complex_inverse_circle
    movq xmm0, rax
    movq xmm1, rcx
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
