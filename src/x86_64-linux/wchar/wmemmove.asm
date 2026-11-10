; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wmemmove
; header: wchar.h
; prototype: wchar_t *wmemmove(wchar_t *dst, const wchar_t *src, size_t n)
; standard: C17 7.29.4.2.4
; deps: memmove
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Copy exactly n wide elements with overlap supported.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wmemmove:function
extern memmove:function

section .text.wmemmove alloc exec nowrite progbits
wmemmove:
    shl rdx, 2
    sub rsp, 8
    call memmove
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
