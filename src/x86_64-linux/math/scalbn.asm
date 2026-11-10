; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: scalbn
; header: math.h
; prototype: double scalbn(double x, int n)
; standard: C17 7.12.6.13
; deps: feraiseexcept, __errno_location, fegetround
; errno: ERANGE
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Multiply x by two raised to the int exponent and round in the active mode.
; semantics: Overflow or a tiny inexact result sets ERANGE and raises the corresponding flags. Exact scaling preserves errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global scalbn:function
extern __al_math_scale:function

section .text.scalbn alloc exec nowrite progbits
scalbn:
    movsxd rcx, edi
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_scale
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
