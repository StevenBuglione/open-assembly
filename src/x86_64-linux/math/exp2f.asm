; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: exp2f
; header: math.h
; prototype: float exp2f(float x)
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

global exp2f:function
extern __al_math_exp:function

section .text.exp2f alloc exec nowrite progbits
exp2f:
    mov ecx, 0
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_exp
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
