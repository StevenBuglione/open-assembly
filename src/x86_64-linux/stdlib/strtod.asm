; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strtod
; header: stdlib.h
; prototype: double strtod(const char *restrict s, char **restrict endptr)
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
; semantics: Round the exact magnitude directly to binary64 using the current floating-point rounding mode.
; semantics: Set endptr to the first unconsumed byte when provided. On no conversion return positive zero and set endptr to s.
; semantics: Preserve errno for exact results, ordinary inexact normal results, and no conversion.
; semantics: Raise inexact for rounding, plus overflow or underflow where applicable. Set ERANGE on overflow or an inexact tiny result.
; semantics: Preserve the sign of zero and infinity. Accept a valid NaN payload and return a canonical quiet NaN.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strtod:function
extern __al_strtof_core:function

section .text.strtod alloc exec nowrite progbits
strtod:
    push rbp
    mov rbp, rsp
    mov edx, 1
    call __al_strtof_core
    movq xmm0, rax
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
