; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atanl
; header: math.h
; prototype: long double atanl(long double x)
; standard: C17 7.12.4.3
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the inverse tangent in radians and use the active rounding mode.
; semantics: Preserve signed zero. Infinite operands produce the signed half-pi result.
; semantics: Quiet signaling NaNs and raise FE_INVALID. An inexact tiny result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atanl:function
extern __al_math_atan:function

section .text.atanl alloc exec nowrite progbits
atanl:
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
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
