; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: iswspace
; header: wctype.h
; prototype: int iswspace(wint_t wc)
; standard: C17 7.30.2.1.10
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:unicode-16.0.0, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Test the space class in the current LC_CTYPE.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global iswspace:function
extern __al_unicode_mask:function

section .text.iswspace alloc exec nowrite progbits
iswspace:
    mov edi, edi
    sub rsp, 8
    call __al_unicode_mask
    and eax, 512
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
