; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getchar
; header: stdio.h
; prototype: int getchar(void)
; standard: C17 7.21.7.6
; deps: fgetc
; errno: EBADF, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Read one byte from stdin with fgetc semantics.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getchar:function
extern fgetc:function
extern stdin:data

section .text.getchar alloc exec nowrite progbits
getchar:
    push rbp
    mov rbp, rsp
    mov rdi, [rel stdin]
    call fgetc
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
