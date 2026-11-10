; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: rewind
; header: stdio.h
; prototype: void rewind(FILE *stream)
; standard: C17 7.21.9.5
; deps: fseek, clearerr
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Seek to the start and clear the error and EOF indicators.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global rewind:function
extern fseek:function
extern clearerr:function

section .text.rewind alloc exec nowrite progbits
rewind:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rdi
    xor esi, esi
    xor edx, edx
    call fseek
    mov rdi, rbx
    call clearerr
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
