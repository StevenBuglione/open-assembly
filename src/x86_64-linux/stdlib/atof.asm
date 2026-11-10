; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: atof
; header: stdlib.h
; prototype: double atof(const char *s)
; standard: C17 7.22.1.1
; deps: strtod
; errno: ERANGE
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, reference:mpfr
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Convert using the same C-locale syntax and binary64 rounding as strtod without an end pointer.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global atof:function
extern strtod:function

section .text.atof alloc exec nowrite progbits
atof:
    push rbp
    mov rbp, rsp
    xor esi, esi
    call strtod
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
