; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wmemcpy
; header: wchar.h
; prototype: wchar_t *wmemcpy(wchar_t *restrict dst, const wchar_t *restrict src, size_t n)
; standard: C17 7.29.4.2.3
; deps: memcpy
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Copy exactly n wide elements in disjoint objects.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wmemcpy:function
extern memcpy:function

section .text.wmemcpy alloc exec nowrite progbits
wmemcpy:
    shl rdx, 2
    sub rsp, 8
    call memcpy
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
