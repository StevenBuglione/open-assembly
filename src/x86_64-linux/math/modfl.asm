; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: modfl
; header: math.h
; prototype: long double modfl(long double x, long double *iptr)
; standard: C17 7.12.6.12
; deps: feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Store the integral part through iptr and return the fractional part. Preserve both signs, including zero.
; semantics: Infinity has a signed zero fractional part. NaN propagates to both results.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global modfl:function
extern __al_math_modf:function

section .text.modfl alloc exec nowrite progbits
modfl:
    mov rcx, rdi
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_modf
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
