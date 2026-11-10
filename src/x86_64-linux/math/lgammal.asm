; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: lgammal
; header: math.h
; prototype: long double lgammal(long double x)
; standard: C17 7.12.8.3
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the natural logarithm of the absolute gamma value. Use the active rounding mode.
; semantics: Zero and negative integers return positive infinity with ERANGE and FE_DIVBYZERO. Either infinite input returns positive infinity.
; semantics: Quiet signaling NaNs with FE_INVALID. Overflow or a tiny inexact result reports ERANGE with the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global lgammal:function
extern __al_math_gamma:function

section .text.lgammal alloc exec nowrite progbits
lgammal:
    xor ecx, ecx
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_gamma
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
