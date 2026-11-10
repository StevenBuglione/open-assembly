; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cbrt
; header: math.h
; prototype: double cbrt(double x)
; standard: C17 7.12.7.1
; deps: fegetround, feraiseexcept
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:exact-rational, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the real cube root, rounded in the active mode. Preserve zero and infinity signs.
; semantics: A finite inexact result raises FE_INEXACT. A signaling NaN is quieted and raises FE_INVALID.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cbrt:function
extern __al_math_root:function

section .text.cbrt alloc exec nowrite progbits
cbrt:
    xor ecx, ecx
    xor r8d, r8d
    mov r9d, 3
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_root
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
