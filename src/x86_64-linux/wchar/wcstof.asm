; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcstof
; header: wchar.h
; prototype: float wcstof(const wchar_t *restrict s, wchar_t **restrict endptr)
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
; semantics: Round the exact magnitude directly to binary32 using the current floating-point rounding mode.
; semantics: Set endptr to the first unconsumed wide character when provided. On no conversion return positive zero and set endptr to s.
; semantics: Preserve errno for exact results, ordinary inexact normal results, and no conversion.
; semantics: Raise inexact for rounding, plus overflow or underflow where applicable. Set ERANGE on overflow or an inexact tiny result.
; semantics: Preserve the sign of zero and infinity. Accept a valid NaN payload and return a canonical quiet NaN.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcstof:function
extern __al_wcstof_core:function

section .text.wcstof alloc exec nowrite progbits
wcstof:
    push rbp
    mov rbp, rsp
    mov edx, 0
    call __al_wcstof_core
    movd xmm0, eax
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
