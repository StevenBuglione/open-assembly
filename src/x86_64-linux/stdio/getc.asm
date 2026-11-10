; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getc
; header: stdio.h
; prototype: int getc(FILE *stream)
; standard: C17 7.21.7.5
; deps: fgetc
; errno: EBADF, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Read one byte with fgetc semantics.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getc:function
extern fgetc:function

section .text.getc alloc exec nowrite progbits
getc:
    push rbp
    mov rbp, rsp
    call fgetc
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
