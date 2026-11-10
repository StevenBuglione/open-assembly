; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: iswgraph
; header: wctype.h
; prototype: int iswgraph(wint_t wc)
; standard: C17 7.30.2.1.6
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:unicode-16.0.0, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Test the graph class in the current LC_CTYPE.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global iswgraph:function
extern __al_unicode_mask:function

section .text.iswgraph alloc exec nowrite progbits
iswgraph:
    mov edi, edi
    sub rsp, 8
    call __al_unicode_mask
    and eax, 32
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
