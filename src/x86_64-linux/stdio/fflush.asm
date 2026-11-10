; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fflush
; header: stdio.h
; prototype: int fflush(FILE *stream)
; standard: C17 7.21.5.2
; deps: -
; errno: EBADF, EIO, ESPIPE
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Flush pending output, or synchronize the buffered read position of a seekable input stream.
; semantics: A NULL stream flushes all open output streams. Return zero on success or EOF on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fflush:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_streams:data
extern __al_stream_flush:function

section .text.fflush alloc exec nowrite progbits
fflush:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rdi
    xor r12d, r12d
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    test rbx, rbx
    jz .all
    mov rdi, rbx
    call __al_stream_flush
    mov r12d, eax
    jmp .unlock
.all:
    mov rbx, [rel __al_streams]
.next:
    test rbx, rbx
    jz .unlock
    cmp qword [rbx + 56], 2
    jne .advance
    mov rdi, rbx
    call __al_stream_flush
    or r12d, eax
.advance:
    mov rbx, [rbx + 16]
    jmp .next
.unlock:
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    mov eax, r12d
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
