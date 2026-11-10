; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: scalbnl
; header: math.h
; prototype: long double scalbnl(long double x, int n)
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

global scalbnl:function
extern __al_math_scale:function

section .text.scalbnl alloc exec nowrite progbits
scalbnl:
    movsxd rcx, edi
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_scale
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
