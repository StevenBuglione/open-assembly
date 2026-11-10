; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: putwchar
; header: wchar.h
; prototype: wint_t putwchar(wchar_t character)
; standard: C17 7.29.3.9
; deps: fputwc
; errno: EBADF, EILSEQ, EIO
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Write one wide character to stdout as fputwc.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global putwchar:function
extern fputwc:function
extern stdout:data

section .text.putwchar alloc exec nowrite progbits
putwchar:
    movsxd rdi, edi
    mov rsi, [rel stdout]
    sub rsp, 8
    call fputwc
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
