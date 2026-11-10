; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: iswlower
; header: wctype.h
; prototype: int iswlower(wint_t wc)
; standard: C17 7.30.2.1.7
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:unicode-16.0.0, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Test the lower class in the current LC_CTYPE.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global iswlower:function
extern __al_unicode_mask:function

section .text.iswlower alloc exec nowrite progbits
iswlower:
    mov edi, edi
    sub rsp, 8
    xor esi, esi          ; select the active locale
    call __al_unicode_mask
    and eax, 64
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
