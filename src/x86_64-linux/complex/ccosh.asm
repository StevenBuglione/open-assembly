; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ccosh
; header: complex.h
; prototype: double _Complex ccosh(double _Complex z)
; standard: C17 7.3.6.4
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:complex-branch-cut, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the complex hyperbolic cosine, with final range effects assessed for each component. Conjugation preserves the real result and reflects the sign of the imaginary result.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ccosh:function
extern __al_complex_product:function

section .text.ccosh alloc exec nowrite progbits
ccosh:
    movq rsi, xmm0
    movq rcx, xmm1
    xor edx, edx
    xor r8d, r8d
    mov edi, 1
    mov r9d, 0
    sub rsp, 8
    call __al_complex_product
    movq xmm0, rax
    movq xmm1, rcx
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
