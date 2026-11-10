; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cbrtl
; header: math.h
; prototype: long double cbrtl(long double x)
; standard: C17 7.12.7.1
; deps: fegetround, feraiseexcept
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:exact-rational, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the real cube root, rounded in the active mode. Preserve zero and infinity signs.
; semantics: A finite inexact result raises FE_INEXACT. A signaling NaN is quieted and raises FE_INVALID.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cbrtl:function
extern __al_math_root:function

section .text.cbrtl alloc exec nowrite progbits
cbrtl:
    xor ecx, ecx
    xor r8d, r8d
    mov r9d, 3
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_root
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
