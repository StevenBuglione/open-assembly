; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: llroundf
; header: math.h
; prototype: long long llroundf(float x)
; standard: C17 7.12.9.7
; deps: __errno_location, feraiseexcept
; errno: EDOM
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Choose the nearest integer with ties away from zero and preserve FE_INEXACT.
; semantics: For infinity, NaN, or a result outside the signed return type, return the signed minimum and report EDOM and FE_INVALID.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global llroundf:function
extern __al_math_roundint:function

section .text.llroundf alloc exec nowrite progbits
llroundf:
    mov ecx, 1
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_roundint
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
