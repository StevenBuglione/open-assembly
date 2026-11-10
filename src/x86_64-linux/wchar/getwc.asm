; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getwc
; header: wchar.h
; prototype: wint_t getwc(FILE *stream)
; standard: C17 7.29.3.6
; deps: fgetwc
; errno: EBADF, EILSEQ, EIO
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Read one wide character as fgetwc.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getwc:function
extern fgetwc:function

section .text.getwc alloc exec nowrite progbits
getwc:
    sub rsp, 8
    call fgetwc
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
