; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ftell
; header: stdio.h
; prototype: long ftell(FILE *stream)
; standard: C17 7.21.9.4
; deps: -
; errno: EBADF, ESPIPE, EOVERFLOW
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the current logical byte offset including buffering, or -1 on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ftell:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_stdio_seek:function
extern __al_stdio_errno:function
extern __al_stream_flush:function

section .text.ftell alloc exec nowrite progbits
ftell:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rdi
    mov r12, -1
    mov rdi, rbx
    call __al_stream_lock
    cmp qword [rbx], 0
    jl .closed
    cmp qword [rbx + 56], 2
    jne .query
    test qword [rbx + 8], 4       ; actual O_APPEND offset is chosen by write
    jz .query
    mov rdi, rbx
    call __al_stream_flush
    test eax, eax
    jnz .unlock
.query:
    mov rdi, [rbx]
    xor esi, esi
    mov edx, 1
    call __al_stdio_seek
    test rax, rax
    js .unlock
    cmp qword [rbx + 56], 2
    je .write_pos
    cmp qword [rbx + 56], 1
    jne .record
    mov rcx, [rbx + 48]
    sub rcx, [rbx + 40]
    cmp qword [rbx + 72], -1
    je .subtract
    inc rcx
.subtract:
    sub rax, rcx
    js .overflow
    jmp .record
.write_pos:
    add rax, [rbx + 48]
    jo .overflow
.record:
    mov r12, rax
    jmp .unlock
.closed:
    mov edi, 9
    jmp .errno
.overflow:
    mov edi, 75
.errno:
    call __al_stdio_errno
.unlock:
    mov rdi, rbx
    call __al_stream_unlock
    mov rax, r12
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
