; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fminl
; header: math.h
; prototype: long double fminl(long double x, long double y)
; standard: C17 7.12.12.3
; deps: feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the lesser numeric operand and select negative zero when the two zeros have different signs.
; semantics: Ignore one quiet NaN in favor of a numeric operand. Quiet and return a signaling NaN with FE_INVALID. If both are quiet NaNs, return the first.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fminl:function
extern __al_math_minmax:function

section .text.fminl alloc exec nowrite progbits
fminl:
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov r9d, 0
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
