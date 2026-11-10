; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ctanhl
; header: complex.h
; prototype: long double _Complex ctanhl(long double _Complex z)
; standard: C17 7.3.6.6
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:complex-branch-cut, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the complex hyperbolic tangent, with final range effects assessed for each component. Conjugation preserves the real result and reflects the sign of the imaginary result.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ctanhl:function
extern __al_complex_tangent:function

section .text.ctanhl alloc exec nowrite progbits
ctanhl:
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov edi, 2
    mov r9d, 0
    sub rsp, 40
    call __al_complex_tangent
    mov [rsp], rax
    mov [rsp + 8], dx
    mov [rsp + 16], rcx
    mov [rsp + 24], r8w
    fld tword [rsp + 16]
    fld tword [rsp]
    add rsp, 40
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
