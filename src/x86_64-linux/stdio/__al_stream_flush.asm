; Original locked stream flush. rdi = stream. Returns 0 or -1.
bits 64
default rel

global __al_stream_flush:function
extern __al_stdio_io:function
extern __al_stdio_seek:function
extern __al_stdio_errno:function
extern memmove:function

section .text.__al_stream_flush alloc exec nowrite progbits
__al_stream_flush:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    cmp qword [rbx], 0
    jl .closed
    mov rax, [rbx + 56]           ; direction
    cmp rax, 1
    je .input
    cmp rax, 2
    jne .reset
    mov r12, [rbx + 24]           ; start of output buffer
    mov r13, r12                  ; current output cursor
    mov r14, [rbx + 48]           ; unwritten byte count
.output:
    test r14, r14
    jz .reset
    mov edi, 1
    mov rsi, [rbx]
    mov rdx, r13
    mov rcx, r14
    call __al_stdio_io
    test rax, rax
    js .retain
    jz .zero_write
    add r13, rax
    sub r14, rax
    jmp .output
.zero_write:
    mov edi, 5                    ; EIO: no progress on nonempty output
    call __al_stdio_errno
.retain:
    cmp r12, r13
    je .save_pending
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    call memmove
.save_pending:
    mov [rbx + 48], r14
    jmp .error

.input:
    mov rsi, [rbx + 48]
    sub rsi, [rbx + 40]           ; bytes read ahead
    mov eax, [rbx + 160]
    add rsi, rax
    cmp qword [rbx + 72], -1
    je .reposition
    inc rsi                      ; pending pushback is also logically unread
.reposition:
    test rsi, rsi
    jz .input_reset
    neg rsi
    mov rdi, [rbx]
    mov edx, 1                    ; SEEK_CUR
    call __al_stdio_seek
    test rax, rax
    js .error
.input_reset:
    mov rax, [rbx + 136]
    cmp dword [rbx + 148], -1
    je .clear
    mov rax, [rbx + 168]
    jmp .clear
.reset:
    xor eax, eax
.clear:
    mov qword [rbx + 40], 0
    mov qword [rbx + 48], 0
    mov qword [rbx + 56], 0
    mov qword [rbx + 72], -1
    mov [rbx + 136], rax
    mov qword [rbx + 144], -1
    mov dword [rbx + 160], 0
    xor eax, eax
    jmp .done
.closed:
    mov edi, 9                    ; EBADF
    call __al_stdio_errno
.error:
    or qword [rbx + 8], 32
    mov rax, -1
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
