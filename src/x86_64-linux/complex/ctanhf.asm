; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ctanhf
; header: complex.h
; prototype: float _Complex ctanhf(float _Complex z)
; standard: C17 7.3.6.6
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:complex-branch-cut, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the complex hyperbolic tangent, with final range effects assessed for each component. Conjugation preserves the real result and reflects the sign of the imaginary result.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ctanhf:function
extern __al_complex_tangent:function

section .text.ctanhf alloc exec nowrite progbits
ctanhf:
    movq rsi, xmm0
    mov rcx, rsi
    shr rcx, 32
    mov esi, esi
    xor edx, edx
    xor r8d, r8d
    mov edi, 0
    mov r9d, 0
    sub rsp, 8
    call __al_complex_tangent
    mov eax, eax
    shl rcx, 32
    or rax, rcx
    movq xmm0, rax
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
