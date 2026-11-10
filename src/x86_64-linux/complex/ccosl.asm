; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ccosl
; header: complex.h
; prototype: long double _Complex ccosl(long double _Complex z)
; standard: C17 7.3.5.4
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:complex-branch-cut, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the complex cosine, with final range effects assessed for each component. Conjugation preserves the real result and reflects the sign of the imaginary result.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ccosl:function
extern __al_complex_product:function

section .text.ccosl alloc exec nowrite progbits
ccosl:
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov edi, 2
    mov r9d, 2
    sub rsp, 40
    call __al_complex_product
    mov [rsp], rax
    mov [rsp + 8], dx
    mov [rsp + 16], rcx
    mov [rsp + 24], r8w
    fld tword [rsp + 16]
    fld tword [rsp]
    add rsp, 40
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
