; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: erfl
; header: math.h
; prototype: long double erfl(long double x)
; standard: C17 7.12.8.1
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the error function in the active rounding mode.
; semantics: Preserve signed zero and return signed one for infinity.
; semantics: Quiet signaling NaNs and raise FE_INVALID. A tiny inexact result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global erfl:function
extern __al_math_erf:function

section .text.erfl alloc exec nowrite progbits
erfl:
    xor ecx, ecx
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_erf
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
