; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cargl
; header: complex.h
; prototype: long double cargl(long double _Complex z)
; standard: C17 7.3.9.1
; deps: atan2l
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:ieee-bits, reference:mpfr, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the signed angle in radians with the quadrant, signed-zero and exception rules of atan2 of imaginary and real.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cargl:function
extern __al_math_atan:function

section .text.cargl alloc exec nowrite progbits
cargl:
    mov edi, 2
    mov rsi, [rsp + 24]
    movzx edx, word [rsp + 32]
    mov rcx, [rsp + 8]
    movzx r8d, word [rsp + 16]
    mov r9d, 1
    sub rsp, 24
    call __al_math_atan
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
