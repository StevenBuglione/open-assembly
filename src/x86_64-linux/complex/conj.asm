; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: conj
; header: complex.h
; prototype: double _Complex conj(double _Complex z)
; standard: C17 7.3.9.4
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:ieee-bits, reference:mpfr, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Reverse the imaginary sign bit and preserve the real component, other bits and floating environment.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global conj:function

section .text.conj alloc exec nowrite progbits
conj:
    movq rax, xmm1
    mov rdx, 0x8000000000000000
    xor rax, rdx
    movq xmm1, rax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
