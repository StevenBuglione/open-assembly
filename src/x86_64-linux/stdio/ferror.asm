; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ferror
; header: stdio.h
; prototype: int ferror(FILE *stream)
; standard: C17 7.21.10.3
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return nonzero if the error indicator is set, or zero otherwise.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ferror:function
extern __al_stream_lock:function
extern __al_stream_unlock:function

section .text.ferror alloc exec nowrite progbits
ferror:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rdi
    mov rdi, rbx
    call __al_stream_lock
    mov r12, [rbx + 8]
    and r12d, 32
    mov rdi, rbx
    call __al_stream_unlock
    mov eax, r12d
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
