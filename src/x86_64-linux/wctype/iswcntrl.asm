; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: iswcntrl
; header: wctype.h
; prototype: int iswcntrl(wint_t wc)
; standard: C17 7.30.2.1.4
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:unicode-16.0.0, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Test the cntrl class in the current LC_CTYPE.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global iswcntrl:function
extern __al_unicode_mask:function

section .text.iswcntrl alloc exec nowrite progbits
iswcntrl:
    mov edi, edi
    sub rsp, 8
    xor esi, esi          ; select the active locale
    call __al_unicode_mask
    and eax, 8
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
