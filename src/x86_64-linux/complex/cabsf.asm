; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cabsf
; header: complex.h
; prototype: float cabsf(float _Complex z)
; standard: C17 7.3.8.1
; deps: hypotf
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

global cabsf:function
extern hypotf:function

section .text.cabsf alloc exec nowrite progbits
cabsf:
    movq rax, xmm0
    shr rax, 32
    movd xmm1, eax
    sub rsp, 8
    call hypotf
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
