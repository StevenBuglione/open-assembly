; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: iswprint
; header: wctype.h
; prototype: int iswprint(wint_t wc)
; standard: C17 7.30.2.1.8
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:unicode-16.0.0, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Test the print class in the current LC_CTYPE.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global iswprint:function
extern __al_unicode_mask:function

section .text.iswprint alloc exec nowrite progbits
iswprint:
    mov edi, edi
    sub rsp, 8
    call __al_unicode_mask
    and eax, 128
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
