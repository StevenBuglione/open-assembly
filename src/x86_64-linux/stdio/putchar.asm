; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: putchar
; header: stdio.h
; prototype: int putchar(int c)
; standard: C17 7.21.7.8
; deps: fputc
; errno: EBADF, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Write one byte to stdout with fputc semantics.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global putchar:function
extern fputc:function
extern stdout:data

section .text.putchar alloc exec nowrite progbits
putchar:
    push rbp
    mov rbp, rsp
    movsxd rdi, edi
    mov rsi, [rel stdout]
    call fputc
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
