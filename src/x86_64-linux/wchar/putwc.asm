; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: putwc
; header: wchar.h
; prototype: wint_t putwc(wchar_t character, FILE *stream)
; standard: C17 7.29.3.8
; deps: fputwc
; errno: EBADF, EILSEQ, EIO
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Write one wide character as fputwc.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global putwc:function
extern fputwc:function

section .text.putwc alloc exec nowrite progbits
putwc:
    movsxd rdi, edi
    sub rsp, 8
    call fputwc
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
