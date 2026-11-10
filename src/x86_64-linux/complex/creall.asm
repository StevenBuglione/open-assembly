; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: creall
; header: complex.h
; prototype: long double creall(long double _Complex z)
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

global creall:function

section .text.creall alloc exec nowrite progbits
creall:
    fld tword [rsp + 8]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
