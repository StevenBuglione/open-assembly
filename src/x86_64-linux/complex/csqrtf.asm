; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: csqrtf
; header: complex.h
; prototype: float _Complex csqrtf(float _Complex z)
; standard: C17 7.3.8.3
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:complex-branch-cut, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the principal square root with a nonnegative real part and imaginary sign from the input. The branch cut is the negative real axis.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global csqrtf:function
extern __al_complex_sqrt:function

section .text.csqrtf alloc exec nowrite progbits
csqrtf:
    movq rsi, xmm0
    mov rcx, rsi
    shr rcx, 32
    mov esi, esi
    xor edx, edx
    xor r8d, r8d
    mov edi, 0
    sub rsp, 8
    call __al_complex_sqrt
    mov eax, eax
    shl rcx, 32
    or rax, rcx
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
