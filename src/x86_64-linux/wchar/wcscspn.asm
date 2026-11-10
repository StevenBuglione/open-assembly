; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcscspn
; header: wchar.h
; prototype: size_t wcscspn(const wchar_t *s, const wchar_t *reject)
; standard: C17 7.29.4.5.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Count the initial wide elements absent from the rejection set.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcscspn:function
extern __al_wide_span:function

section .text.wcscspn alloc exec nowrite progbits
wcscspn:
    mov edx, 0
    sub rsp, 8
    call __al_wide_span
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
