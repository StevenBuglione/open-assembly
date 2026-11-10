; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: csqrtl
; header: complex.h
; prototype: long double _Complex csqrtl(long double _Complex z)
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

global csqrtl:function
extern __al_complex_sqrt:function

section .text.csqrtl alloc exec nowrite progbits
csqrtl:
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov edi, 2
    sub rsp, 40
    call __al_complex_sqrt
    mov [rsp], rax
    mov [rsp + 8], dx
    mov [rsp + 16], rcx
    mov [rsp + 24], r8w
    fld tword [rsp + 16]
    fld tword [rsp]
    add rsp, 40
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
