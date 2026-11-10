; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cabs
; header: complex.h
; prototype: double cabs(double _Complex z)
; standard: C17 7.3.8.1
; deps: hypot
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:ieee-bits, reference:mpfr, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the magnitude using the exact sum of squares and final square-root rounding. Follow the corresponding hypot range and floating exception contract.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cabs:function
extern hypot:function

section .text.cabs alloc exec nowrite progbits
cabs:
    sub rsp, 8
    call hypot
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
