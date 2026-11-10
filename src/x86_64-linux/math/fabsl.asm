; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fabsl
; header: math.h
; prototype: long double fabsl(long double x)
; standard: C17 7.12.7.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Clear the sign of x and preserve the other value bits.
; semantics: This bit operation preserves errno and floating exception flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fabsl:function

section .text.fabsl alloc exec nowrite progbits
fabsl:
    mov rax, [rsp + 8]
    movzx edx, word [rsp + 16]
    and edx, 0x7fff
    sub rsp, 16
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 16
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
