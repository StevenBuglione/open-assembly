; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atan2l
; header: math.h
; prototype: long double atan2l(long double y, long double x)
; standard: C17 7.12.4.4
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the inverse tangent in radians and use the active rounding mode.
; semantics: Use both signs to select the quadrant, including for signed zeros and infinities.
; semantics: Quiet signaling NaNs and raise FE_INVALID. An inexact tiny result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atan2l:function
extern __al_math_atan:function

section .text.atan2l alloc exec nowrite progbits
atan2l:
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov r9d, 1
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_atan
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
