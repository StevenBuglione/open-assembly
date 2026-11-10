; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: scalblnf
; header: math.h
; prototype: float scalblnf(float x, long n)
; standard: C17 7.12.6.13
; deps: feraiseexcept, __errno_location, fegetround
; errno: ERANGE
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Multiply x by two raised to the long exponent and round in the active mode.
; semantics: Handle large exponents without integer overflow. Overflow and tiny inexact results set ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global scalblnf:function
extern __al_math_scale:function

section .text.scalblnf alloc exec nowrite progbits
scalblnf:
    mov rcx, rdi
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_scale
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
