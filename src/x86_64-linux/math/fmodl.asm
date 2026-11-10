; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fmodl
; header: math.h
; prototype: long double fmodl(long double x, long double y)
; standard: C17 7.12.10.1
; deps: __errno_location, feraiseexcept
; errno: EDOM
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the exact remainder with the sign of x, using a quotient truncated toward zero.
; semantics: A zero divisor or infinite dividend reports EDOM and FE_INVALID and returns a quiet NaN. A NaN operand takes precedence over those domain errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fmodl:function
extern __al_math_rem:function

section .text.fmodl alloc exec nowrite progbits
fmodl:
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov r9d, 0
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_rem
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
