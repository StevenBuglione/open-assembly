; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: crealf
; header: complex.h
; prototype: float crealf(float _Complex z)
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

global crealf:function

section .text.crealf alloc exec nowrite progbits
crealf:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
