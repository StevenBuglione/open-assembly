; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fdimf
; header: math.h
; prototype: float fdimf(float x, float y)
; standard: C17 7.12.12.1
; deps: fmaf, feraiseexcept, __errno_location
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

global fdimf:function
extern __al_math_fdim:function

section .text.fdimf alloc exec nowrite progbits
fdimf:
    movd ecx, xmm1
    xor r8d, r8d
    movd esi, xmm0
    xor edx, edx
    mov edi, 0
    sub rsp, 8
    call __al_math_fdim
    movd xmm0, eax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
