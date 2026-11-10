; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: copysignl
; header: math.h
; prototype: long double copysignl(long double x, long double y)
; standard: C17 7.12.11.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the magnitude of x with the sign bit of y.
; semantics: Preserve errno and floating exception flags, including for NaN inputs.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global copysignl:function

section .text.copysignl alloc exec nowrite progbits
copysignl:
    mov rax, [rsp + 8]
    movzx edx, word [rsp + 16]
    movzx ecx, word [rsp + 32]
    and edx, 0x7fff
    and ecx, 0x8000
    or edx, ecx
    sub rsp, 16
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 16
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
