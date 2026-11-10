; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: iswxdigit
; header: wctype.h
; prototype: int iswxdigit(wint_t wc)
; standard: C17 7.30.2.1.12
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:unicode-16.0.0, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Test the xdigit class in the current LC_CTYPE.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global iswxdigit:function
extern __al_unicode_mask:function

section .text.iswxdigit alloc exec nowrite progbits
iswxdigit:
    mov edi, edi
    sub rsp, 8
    call __al_unicode_mask
    and eax, 2048
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
