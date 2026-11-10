; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cargf
; header: complex.h
; prototype: float cargf(float _Complex z)
; standard: C17 7.3.9.1
; deps: atan2f
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:ieee-bits, reference:mpfr, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the signed angle in radians with the quadrant, signed-zero and exception rules of atan2 of imaginary and real.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cargf:function
extern atan2f:function

section .text.cargf alloc exec nowrite progbits
cargf:
    movq rax, xmm0
    movd xmm1, eax
    shr rax, 32
    movd xmm0, eax
    sub rsp, 8
    call atan2f
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
