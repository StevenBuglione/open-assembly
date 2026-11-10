; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: conjl
; header: complex.h
; prototype: long double _Complex conjl(long double _Complex z)
; standard: C17 7.3.9.4
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:ieee-bits, reference:mpfr, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Reverse the imaginary sign bit and preserve the real component, other bits and floating environment.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global conjl:function

section .text.conjl alloc exec nowrite progbits
conjl:
    mov rax, [rsp + 24]
    movzx ecx, word [rsp + 32]
    xor ecx, 0x8000
    sub rsp, 16
    mov [rsp], rax
    mov [rsp + 8], cx
    fld tword [rsp]
    add rsp, 16
    fld tword [rsp + 8]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
