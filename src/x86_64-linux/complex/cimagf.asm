; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cimagf
; header: complex.h
; prototype: float cimagf(float _Complex z)
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

global cimagf:function

section .text.cimagf alloc exec nowrite progbits
cimagf:
    movq rax, xmm0
    shr rax, 32
    movd xmm0, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
