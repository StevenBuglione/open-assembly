; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: carg
; header: complex.h
; prototype: double carg(double _Complex z)
; standard: C17 7.3.9.1
; deps: atan2
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:ieee-bits, reference:mpfr, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the signed angle in radians with the quadrant, signed-zero and exception rules of atan2 of imaginary and real.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global carg:function
extern atan2:function

section .text.carg alloc exec nowrite progbits
carg:
    movsd xmm2, xmm0
    movsd xmm0, xmm1
    movsd xmm1, xmm2
    sub rsp, 8
    call atan2
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
