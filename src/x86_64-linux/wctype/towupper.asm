; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: towupper
; header: wctype.h
; prototype: wint_t towupper(wint_t wc)
; standard: C17 7.30.3.1.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:unicode-16.0.0, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Apply the corresponding simple uppercase mapping or return the original value.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global towupper:function
extern __al_unicode_case:function

section .text.towupper alloc exec nowrite progbits
towupper:
    mov edi, edi
    mov esi, 1
    sub rsp, 8
    xor edx, edx          ; select the active locale
    call __al_unicode_case
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
