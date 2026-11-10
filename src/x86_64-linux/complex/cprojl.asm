; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cprojl
; header: complex.h
; prototype: long double _Complex cprojl(long double _Complex z)
; standard: C17 7.3.9.5
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:ieee-bits, reference:mpfr, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: If either component is infinite, return positive real infinity and imaginary zero with the original imaginary sign. Otherwise preserve both components.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cprojl:function

section .text.cprojl alloc exec nowrite progbits
cprojl:
    mov r8, 0x8000000000000000
    movzx eax, word [rsp + 16]
    and eax, 0x7fff
    cmp eax, 0x7fff
    jne .imaginary
    cmp [rsp + 8], r8
    je .infinite
.imaginary:
    movzx eax, word [rsp + 32]
    and eax, 0x7fff
    cmp eax, 0x7fff
    jne .original
    cmp [rsp + 24], r8
    jne .original
.infinite:
    movzx ecx, word [rsp + 32]
    and ecx, 0x8000
    sub rsp, 32
    mov qword [rsp], 0
    mov [rsp + 8], cx
    mov [rsp + 16], r8
    mov word [rsp + 24], 0x7fff
    fld tword [rsp]
    fld tword [rsp + 16]
    add rsp, 32
    ret
.original:
    fld tword [rsp + 24]
    fld tword [rsp + 8]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
