; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: clog
; header: complex.h
; prototype: double _Complex clog(double _Complex z)
; standard: C17 7.3.7.2
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:complex-branch-cut, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the natural logarithm with real part log of the magnitude and imaginary part the signed argument. The branch cut is the negative real axis.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global clog:function
extern __al_complex_log:function

section .text.clog alloc exec nowrite progbits
clog:
    movq rsi, xmm0
    movq rcx, xmm1
    xor edx, edx
    xor r8d, r8d
    mov edi, 1
    sub rsp, 8
    call __al_complex_log
    movq xmm0, rax
    movq xmm1, rcx
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
