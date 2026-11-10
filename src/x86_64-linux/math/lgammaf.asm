; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: lgammaf
; header: math.h
; prototype: float lgammaf(float x)
; standard: C17 7.12.8.3
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the natural logarithm of the absolute gamma value. Use the active rounding mode.
; semantics: Zero and negative integers return positive infinity with ERANGE and FE_DIVBYZERO. Either infinite input returns positive infinity.
; semantics: Quiet signaling NaNs with FE_INVALID. Overflow or a tiny inexact result reports ERANGE with the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global lgammaf:function
extern __al_math_gamma:function
extern __al_math_scale:function
extern __al_lgammaf_fast:function

section .text.lgammaf alloc exec nowrite progbits
lgammaf:
    movd esi, xmm0
    sub rsp, 8
    cmp esi, 0x7c800000           ; positive finite x >= 2^122
    jb .estimate
    cmp esi, 0x7f800000
    jae .estimate
    xor edi, edi
    mov esi, 0x3f800000
    xor edx, edx
    mov ecx, 65536
    call __al_math_scale
    jmp .done
.estimate:
    mov [rsp], esi
    mov edi, esi
    call __al_lgammaf_fast
    test edx, edx
    jnz .done
    mov esi, [rsp]
    xor ecx, ecx
    xor edx, edx
    xor edi, edi
    call __al_math_gamma
.done:
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
