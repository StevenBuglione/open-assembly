; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: casinhl
; header: complex.h
; prototype: long double _Complex casinhl(long double _Complex z)
; standard: C17 7.3.6.2
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:complex-branch-cut, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the complex arc hyperbolic sine on the principal branch, preserving the input side of the branch cut and the floating control state.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global casinhl:function
extern __al_complex_inverse_circle:function

section .text.casinhl alloc exec nowrite progbits
casinhl:
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov edi, 2
    mov r9d, 2
    sub rsp, 40
    call __al_complex_inverse_circle
    mov [rsp], rax
    mov [rsp + 8], dx
    mov [rsp + 16], rcx
    mov [rsp + 24], r8w
    fld tword [rsp + 16]
    fld tword [rsp]
    add rsp, 40
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
