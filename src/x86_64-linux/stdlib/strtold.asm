; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strtold
; header: stdlib.h
; prototype: long double strtold(const char *restrict s, char **restrict endptr)
; standard: C17 7.22.1.3
; deps: fegetround, feraiseexcept, __errno_location
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, reference:mpfr
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Consume C-locale whitespace, optional sign, and the longest valid decimal, hexadecimal, infinity or NaN subject.
; semantics: Round the exact magnitude directly to x86 extended precision using the current floating-point rounding mode.
; semantics: Set endptr to the first unconsumed byte when provided. On no conversion return positive zero and set endptr to s.
; semantics: Preserve errno for exact results, ordinary inexact normal results, and no conversion.
; semantics: Raise inexact for rounding, plus overflow or underflow where applicable. Set ERANGE on overflow or an inexact tiny result.
; semantics: Preserve the sign of zero and infinity. Accept a valid NaN payload and return a canonical quiet NaN.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strtold:function
extern __al_strtof_core:function

section .text.strtold alloc exec nowrite progbits
strtold:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov edx, 2
    call __al_strtof_core
    mov [rsp], rax
    mov [rsp + 8], dx
    fld tword [rsp]
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
