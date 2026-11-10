; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: creal
; header: complex.h
; prototype: double creal(double _Complex z)
; standard: C17 7.3.9.6
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:ieee-bits, reference:mpfr, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the real component without changing its representation or the floating environment.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global creal:function

section .text.creal alloc exec nowrite progbits
creal:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
