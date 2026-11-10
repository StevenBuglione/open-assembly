; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fdim
; header: math.h
; prototype: double fdim(double x, double y)
; standard: C17 7.12.12.1
; deps: fma, feraiseexcept, __errno_location
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

global fdim:function
extern __al_math_fdim:function

section .text.fdim alloc exec nowrite progbits
fdim:
    movq rcx, xmm1
    xor r8d, r8d
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_fdim
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
