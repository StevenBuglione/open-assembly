; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cacosh
; header: complex.h
; prototype: double _Complex cacosh(double _Complex z)
; standard: C17 7.3.6.1
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:complex-branch-cut, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the complex arc hyperbolic cosine on the principal branch, preserving the input side of the branch cut and the floating control state.
; semantics: On the zero-real NaN case, return a quiet NaN real part and an imaginary magnitude of pi over two, as resolved by WG14 DR 471.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cacosh:function
extern __al_complex_inverse_circle:function

section .text.cacosh alloc exec nowrite progbits
cacosh:
    movq rsi, xmm0
    movq rcx, xmm1
    xor edx, edx
    xor r8d, r8d
    mov edi, 1
    mov r9d, 3
    sub rsp, 8
    call __al_complex_inverse_circle
    movq xmm0, rax
    movq xmm1, rcx
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
