; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: casinhf
; header: complex.h
; prototype: float _Complex casinhf(float _Complex z)
; standard: C17 7.3.6.2
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:complex-branch-cut, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the complex arc hyperbolic sine on the principal branch, preserving the input side of the branch cut and the floating control state.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global casinhf:function
extern __al_complex_inverse_circle:function

section .text.casinhf alloc exec nowrite progbits
casinhf:
    movq rsi, xmm0
    mov rcx, rsi
    shr rcx, 32
    mov esi, esi
    xor edx, edx
    xor r8d, r8d
    mov edi, 0
    mov r9d, 2
    sub rsp, 8
    call __al_complex_inverse_circle
    mov eax, eax
    shl rcx, 32
    or rax, rcx
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
