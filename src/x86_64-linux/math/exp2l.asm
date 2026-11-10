; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: exp2l
; header: math.h
; prototype: long double exp2l(long double x)
; standard: C17 7.12.6.2
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute two raised to x in the active rounding mode. Integer arguments use the exact scaling path.
; semantics: Return one for either zero, positive zero for negative infinity, and positive infinity for positive infinity.
; semantics: Quiet signaling NaNs and raise FE_INVALID. Overflow or an inexact tiny result reports ERANGE with the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global exp2l:function
extern __al_math_exp:function

section .text.exp2l alloc exec nowrite progbits
exp2l:
    mov ecx, 0
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_exp
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
