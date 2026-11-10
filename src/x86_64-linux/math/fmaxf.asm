; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fmaxf
; header: math.h
; prototype: float fmaxf(float x, float y)
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

global fmaxf:function
extern __al_math_minmax:function

section .text.fmaxf alloc exec nowrite progbits
fmaxf:
    movd ecx, xmm1
    xor r8d, r8d
    mov r9d, 1
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_minmax
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
