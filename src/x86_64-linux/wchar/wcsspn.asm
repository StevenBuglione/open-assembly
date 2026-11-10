; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcsspn
; header: wchar.h
; prototype: size_t wcsspn(const wchar_t *s, const wchar_t *accept)
; standard: C17 7.29.4.5.5
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Count the initial wide elements contained in the acceptance set.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcsspn:function
extern __al_wide_span:function

section .text.wcsspn alloc exec nowrite progbits
wcsspn:
    mov edx, 1
    sub rsp, 8
    call __al_wide_span
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
