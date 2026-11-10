; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: hypot
; header: math.h
; prototype: double hypot(double x, double y)
; standard: C17 7.12.7.3
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:exact-rational, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the square root of the exact sum of squares rounded in the active mode. Intermediate range is unbounded.
; semantics: Return positive infinity for an infinite operand, including when the other operand is a quiet NaN.
; semantics: A signaling NaN is quieted and raises FE_INVALID. Overflow or a tiny inexact result reports ERANGE and raises the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global hypot:function
extern __al_math_root:function

section .text.hypot alloc exec nowrite progbits
hypot:
    movq rcx, xmm1
    xor r8d, r8d
    mov r9d, 2
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_root
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
