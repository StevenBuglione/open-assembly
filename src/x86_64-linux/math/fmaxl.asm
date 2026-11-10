; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fmaxl
; header: math.h
; prototype: long double fmaxl(long double x, long double y)
; standard: C17 7.12.12.2
; deps: feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the greater numeric operand and select positive zero when the two zeros have different signs.
; semantics: Ignore one quiet NaN in favor of a numeric operand. Quiet and return a signaling NaN with FE_INVALID. If both are quiet NaNs, return the first.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fmaxl:function
extern __al_math_minmax:function

section .text.fmaxl alloc exec nowrite progbits
fmaxl:
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov r9d, 1
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_minmax
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
