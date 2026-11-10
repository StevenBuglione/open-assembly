; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fmin
; header: math.h
; prototype: double fmin(double x, double y)
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

global fmin:function
extern __al_math_minmax:function

section .text.fmin alloc exec nowrite progbits
fmin:
    movq rcx, xmm1
    xor r8d, r8d
    mov r9d, 0
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_minmax
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
