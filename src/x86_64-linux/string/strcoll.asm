; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strcoll
; header: string.h
; prototype: int strcoll(const char *a, const char *b)
; standard: C17 7.24.4.3
; deps: strcmp
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compare strings in the C locale. The result has the same sign as strcmp.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strcoll:function
extern strcmp:function

section .text.strcoll alloc exec nowrite progbits
strcoll:
    push rbp
    mov rbp, rsp
    call strcmp
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
