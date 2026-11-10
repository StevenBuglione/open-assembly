; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: clearerr
; header: stdio.h
; prototype: void clearerr(FILE *stream)
; standard: C17 7.21.10.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Clear both the EOF and error indicators.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global clearerr:function
extern __al_stream_lock:function
extern __al_stream_unlock:function

section .text.clearerr alloc exec nowrite progbits
clearerr:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rdi
    mov rdi, rbx
    call __al_stream_lock
    and qword [rbx + 8], -49
    mov rdi, rbx
    call __al_stream_unlock
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
