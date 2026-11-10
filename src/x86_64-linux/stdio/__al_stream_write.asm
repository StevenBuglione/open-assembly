; Original locked stream write. rdi = stream, rsi = src, rdx = byte count.
; Returns count in rax and error indicator for this call in rdx.
bits 64
default rel

global __al_stream_write:function
extern __al_stream_flush:function
extern __al_stdio_io:function
extern __al_stdio_errno:function
extern memcpy:function
extern memchr:function

section .text.__al_stream_write alloc exec nowrite progbits
__al_stream_write:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi                  ; next source byte
    mov r13, rdx                  ; remaining source bytes
    xor r14d, r14d                ; transferred bytes
    test r13, r13
    jz .success
    or qword [rbx + 8], 64
    test qword [rbx + 8], 2
    jz .bad_fd
    cmp qword [rbx], 0
    jl .bad_fd
    cmp qword [rbx + 56], 1
    jne .enter_write
    mov rdi, rbx
    call __al_stream_flush
    test eax, eax
    jnz .error
.enter_write:
    mov qword [rbx + 56], 2
    cmp qword [rbx + 32], 0
    je .direct
.buffered:
    mov r15, [rbx + 32]
    sub r15, [rbx + 48]
    jz .flush
    cmp r15, r13
    jbe .check_line
    mov r15, r13
.check_line:
    mov qword [rsp], 0
    cmp qword [rbx + 64], 1
    jne .copy
    mov rdi, r12
    mov esi, 10                   ; LF forces a line-buffered flush
    mov rdx, r15
    call memchr
    test rax, rax
    jz .copy
    sub rax, r12
    lea r15, [rax + 1]
    mov qword [rsp], 1
.copy:
    mov rdi, [rbx + 24]
    add rdi, [rbx + 48]
    mov rsi, r12
    mov rdx, r15
    call memcpy
    add [rbx + 48], r15
    add r12, r15
    add r14, r15
    sub r13, r15
    cmp qword [rsp], 0
    jne .flush
    mov rax, [rbx + 48]
    cmp rax, [rbx + 32]
    je .flush
    test r13, r13
    jnz .buffered
    jmp .success
.flush:
    mov rdi, rbx
    call __al_stream_flush
    test eax, eax
    jnz .flush_error
    test r13, r13
    jnz .enter_write
    jmp .success
.flush_error:
    mov rax, [rbx + 48]           ; newest bytes remaining in the output buffer
    cmp rax, r14
    jb .subtract_pending
    mov rax, r14
.subtract_pending:
    sub r14, rax
    jmp .error

.direct:
    mov edi, 1
    mov rsi, [rbx]
    mov rdx, r12
    mov rcx, r13
    call __al_stdio_io
    test rax, rax
    js .error
    jz .no_progress
    add r12, rax
    add r14, rax
    sub r13, rax
    jnz .direct
.success:
    xor edx, edx
    jmp .done
.no_progress:
    mov edi, 5                    ; EIO
    call __al_stdio_errno
    jmp .error
.bad_fd:
    mov edi, 9                    ; EBADF
    call __al_stdio_errno
.error:
    or qword [rbx + 8], 32
    mov edx, 1
.done:
    mov rax, r14
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
