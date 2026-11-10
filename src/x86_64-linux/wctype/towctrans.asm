; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: towctrans
; header: wctype.h
; prototype: wint_t towctrans(wint_t wc, wctrans_t desc)
; standard: C17 7.30.3.2.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:unicode-16.0.0, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Apply the selected case mapping. A zero descriptor leaves the input unchanged.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global towctrans:function
extern __al_unicode_case:function

section .text.towctrans alloc exec nowrite progbits
towctrans:
    mov edi, edi
    cmp rsi, 1
    jb .original
    cmp rsi, 2
    ja .original
    dec esi
    sub rsp, 8
    call __al_unicode_case
    add rsp, 8
    ret
.original:
    mov eax, edi
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
