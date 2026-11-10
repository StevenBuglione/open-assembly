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
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_stream_snapshot:function
extern __al_stream_unpin:function
extern __al_stream_flush:function
extern free:function

section .text.fflush alloc exec nowrite progbits
fflush:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    xor r12d, r12d
    test rbx, rbx
    jz .all
    call __al_stream_lock
    mov rdi, rbx
    call __al_stream_flush
    mov r12d, eax
    mov rdi, rbx
    call __al_stream_unlock
    jmp .done
.all:
    call __al_stream_snapshot
    test rdx, rdx
    jz .done
    js .failure
    mov r13, rax
    mov r14, rdx
    xor r15d, r15d
.next:
    mov rbx, [r13 + r15*8]
    mov rdi, rbx
    call __al_stream_lock
    cmp qword [rbx], 0
    jl .release
    cmp qword [rbx + 56], 2
    jne .release
    mov rdi, rbx
    call __al_stream_flush
    or r12d, eax
.release:
    mov rdi, rbx
    call __al_stream_unlock
    mov rdi, rbx
    xor esi, esi
    call __al_stream_unpin
    inc r15
    cmp r15, r14
    jb .next
    mov rdi, r13
    call free
    jmp .done
.failure:
    mov r12d, -1
.done:
    mov eax, r12d
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
