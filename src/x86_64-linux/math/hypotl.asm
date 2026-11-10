; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: hypotl
; header: math.h
; prototype: long double hypotl(long double x, long double y)
; standard: C17 7.12.7.3
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: reference:mpfr, reference:exact-rational, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the square root of the exact sum of squares rounded in the active mode. Intermediate range is unbounded.
; semantics: Return positive infinity for an infinite operand, including when the other operand is a quiet NaN.
; semantics: A signaling NaN is quieted and raises FE_INVALID. Overflow or a tiny inexact result reports ERANGE and raises the corresponding flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global hypotl:function
extern __al_math_root:function

section .text.hypotl alloc exec nowrite progbits
hypotl:
    mov rcx, [rsp + 24]
    movzx r8d, word [rsp + 32]
    mov r9d, 2
    mov rsi, [rsp + 8]
    movzx edx, word [rsp + 16]
    mov edi, 2
    sub rsp, 24
    call __al_math_root
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
