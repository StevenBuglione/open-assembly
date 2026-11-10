; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: erfcl
; header: math.h
; prototype: long double erfcl(long double x)
; standard: C17 7.12.8.2
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:fixed-point-interval, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compute the complementary error function in the active rounding mode.
; semantics: Return one for either zero, zero for positive infinity, and two for negative infinity.
; semantics: Quiet signaling NaNs and raise FE_INVALID. A tiny inexact result raises FE_UNDERFLOW and FE_INEXACT with ERANGE.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global erfcl:function
extern __al_math_erf:function

section .text.erfcl alloc exec nowrite progbits
erfcl:
    mov ecx, 1
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
