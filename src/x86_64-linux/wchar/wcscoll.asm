; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcscoll
; header: wchar.h
; prototype: int wcscoll(const wchar_t *a, const wchar_t *b)
; standard: C17 7.29.4.4.2
; deps: wcscmp
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compare wide strings in code-point order in both supported locales.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcscoll:function
extern wcscmp:function

section .text.wcscoll alloc exec nowrite progbits
wcscoll:
    sub rsp, 8
    call wcscmp
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
