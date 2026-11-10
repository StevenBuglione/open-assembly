; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: llrintf
; header: math.h
; prototype: long long llrintf(float x)
; standard: C17 7.12.9.5
; deps: __errno_location, feraiseexcept, fegetround
; errno: EDOM
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Use the current rounding mode and raise FE_INEXACT for an inexact valid result.
; semantics: For infinity, NaN, or a result outside the signed return type, return the signed minimum and report EDOM and FE_INVALID.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global llrintf:function
extern __al_math_roundint:function

section .text.llrintf alloc exec nowrite progbits
llrintf:
    mov ecx, 0
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_roundint
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
