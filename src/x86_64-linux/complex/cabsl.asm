; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cabsl
; header: complex.h
; prototype: long double cabsl(long double _Complex z)
; standard: C17 7.3.8.1
; deps: hypotl
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:ieee-bits, reference:mpfr, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the magnitude using the exact sum of squares and final square-root rounding. Follow the corresponding hypot range and floating exception contract.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cabsl:function
extern __al_math_root:function

section .text.cabsl alloc exec nowrite progbits
cabsl:
    mov edi, 2
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov r9d, 2
    sub rsp, 24
    call __al_math_root
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
