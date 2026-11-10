; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: conjf
; header: complex.h
; prototype: float _Complex conjf(float _Complex z)
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

global conjf:function

section .text.conjf alloc exec nowrite progbits
conjf:
    movq rax, xmm0
    mov rdx, 0x8000000000000000
    xor rax, rdx
    movq xmm0, rax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
