; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cprojf
; header: complex.h
; prototype: float _Complex cprojf(float _Complex z)
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

global cprojf:function

section .text.cprojf alloc exec nowrite progbits
cprojf:
    movq rax, xmm0
    mov rdx, rax
    shr rdx, 32
    and eax, 0x7fffffff
    cmp eax, 0x7f800000
    je .infinite
    mov ecx, edx
    and ecx, 0x7fffffff
    cmp ecx, 0x7f800000
    jne .done
.infinite:
    and edx, 0x80000000
    shl rdx, 32
    or rdx, 0x7f800000
    movq xmm0, rdx
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
