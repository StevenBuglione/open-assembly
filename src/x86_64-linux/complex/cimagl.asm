; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cimagl
; header: complex.h
; prototype: long double cimagl(long double _Complex z)
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

global cimagl:function

section .text.cimagl alloc exec nowrite progbits
cimagl:
    fld tword [rsp + 24]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
