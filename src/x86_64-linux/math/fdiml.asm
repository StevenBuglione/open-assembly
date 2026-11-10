; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fdiml
; header: math.h
; prototype: long double fdiml(long double x, long double y)
; standard: C17 7.12.12.1
; deps: fmal, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:exact-rational, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the positive difference x minus y rounded once in the active mode. Return positive zero when x is no greater than y.
; semantics: Propagate NaNs and report ERANGE for overflow. A signaling NaN raises FE_INVALID.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fdiml:function
extern __al_math_fdim:function

section .text.fdiml alloc exec nowrite progbits
fdiml:
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_fdim
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
