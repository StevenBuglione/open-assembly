; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: copysignf
; header: math.h
; prototype: float copysignf(float x, float y)
; standard: C17 7.12.11.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the magnitude of x with the sign bit of y.
; semantics: Preserve errno and floating exception flags, including for NaN inputs.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global copysignf:function

section .text.copysignf alloc exec nowrite progbits
copysignf:
    movd eax, xmm0
    movd edx, xmm1
    and eax, 0x7fffffff
    and edx, 0x80000000
    or eax, edx
    movd xmm0, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
