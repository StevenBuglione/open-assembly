; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: nanl
; header: math.h
; prototype: long double nanl(const char *tagp)
; standard: C17 7.12.11.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the canonical positive quiet NaN. The payload tag is ignored.
; semantics: Preserve errno and the floating exception flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global nanl:function

section .text.nanl alloc exec nowrite progbits
nanl:
    mov rax, 0xc000000000000000
    mov edx, 0x7fff
    sub rsp, 16
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 16
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
