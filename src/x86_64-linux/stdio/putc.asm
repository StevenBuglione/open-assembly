; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: putc
; header: stdio.h
; prototype: int putc(int c, FILE *stream)
; standard: C17 7.21.7.7
; deps: fputc
; errno: EBADF, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Write one byte with fputc semantics.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global putc:function
extern fputc:function

section .text.putc alloc exec nowrite progbits
putc:
    push rbp
    mov rbp, rsp
    movsxd rdi, edi
    call fputc
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
