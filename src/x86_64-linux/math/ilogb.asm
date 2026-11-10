; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ilogb
; header: math.h
; prototype: int ilogb(double x)
; standard: C17 7.12.6.5
; deps: feraiseexcept, __errno_location
; errno: EDOM
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the exact base-two exponent of the leading bit for finite nonzero x.
; semantics: Return INT_MIN for zero or NaN and INT_MAX for infinity. These cases set EDOM and raise FE_INVALID.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ilogb:function
extern __al_math_logb:function

section .text.ilogb alloc exec nowrite progbits
ilogb:
    mov ecx, 1
    movq rsi, xmm0
    xor edx, edx
    mov edi, 1
    sub rsp, 8
    call __al_math_logb
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
