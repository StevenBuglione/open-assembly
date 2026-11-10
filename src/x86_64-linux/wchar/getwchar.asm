; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getwchar
; header: wchar.h
; prototype: wint_t getwchar(void)
; standard: C17 7.29.3.7
; deps: fgetwc
; errno: EBADF, EILSEQ, EIO
; mt_safe: true
; as_safe: false
; oracles: reference:c17-wide-stdio, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Read one wide character from stdin as fgetwc.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getwchar:function
extern fgetwc:function
extern stdin:data

section .text.getwchar alloc exec nowrite progbits
getwchar:
    mov rdi, [rel stdin]
    sub rsp, 8
    call fgetwc
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
