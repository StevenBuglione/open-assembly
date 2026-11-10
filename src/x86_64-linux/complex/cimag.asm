; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cimag
; header: complex.h
; prototype: double cimag(double _Complex z)
; standard: C17 7.3.9.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:ieee-bits, reference:mpfr, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the imaginary component without changing its representation or the floating environment.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cimag:function

section .text.cimag alloc exec nowrite progbits
cimag:
    movsd xmm0, xmm1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
