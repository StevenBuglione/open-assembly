; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cproj
; header: complex.h
; prototype: double _Complex cproj(double _Complex z)
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

global cproj:function

section .text.cproj alloc exec nowrite progbits
cproj:
    movq rax, xmm0
    movq rdx, xmm1
    mov r8, 0x7ff0000000000000
    shl rax, 1
    shr rax, 1
    cmp rax, r8
    je .infinite
    mov rcx, rdx
    shl rcx, 1
    shr rcx, 1
    cmp rcx, r8
    jne .done
.infinite:
    shr rdx, 63
    shl rdx, 63
    movq xmm0, r8
    movq xmm1, rdx
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
