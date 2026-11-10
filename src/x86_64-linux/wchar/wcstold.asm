; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcstold
; header: wchar.h
; prototype: long double wcstold(const wchar_t *restrict s, wchar_t **restrict endptr)
; standard: C17 7.29.4.1.1
; deps: fegetround, feraiseexcept, __errno_location, iswspace
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, reference:mpfr
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Consume wide whitespace in the active LC_CTYPE, optional sign, and the longest valid decimal, hexadecimal, infinity or NaN subject.
; semantics: Round the exact magnitude directly to x86 extended precision using the current floating-point rounding mode.
; semantics: Set endptr to the first unconsumed wide character when provided. On no conversion return positive zero and set endptr to s.
; semantics: Preserve errno for exact results, ordinary inexact normal results, and no conversion.
; semantics: Raise inexact for rounding, plus overflow or underflow where applicable. Set ERANGE on overflow or an inexact tiny result.
; semantics: Preserve the sign of zero and infinity. Accept a valid NaN payload and return a canonical quiet NaN.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcstold:function
extern __al_wcstof_core:function

section .text.wcstold alloc exec nowrite progbits
wcstold:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov edx, 2
    call __al_wcstof_core
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
