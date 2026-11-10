; Original locked stream read. rdi = stream, rsi = dest, rdx = byte limit.
; Returns count in rax and error indicator for this call in rdx.
bits 64
default rel

global __al_stream_read:function
extern __al_stream_flush:function
extern __al_stdio_io:function
extern __al_stdio_errno:function
extern memcpy:function

section .text.__al_stream_read alloc exec nowrite progbits
__al_stream_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi                  ; next destination byte
    mov r13, rdx                  ; remaining byte limit
    xor r14d, r14d                ; transferred bytes
    test r13, r13
    jz .success
    or qword [rbx + 8], 64        ; an I/O operation has started
    test qword [rbx + 8], 1
    jz .bad_fd
    cmp qword [rbx], 0
    jl .bad_fd
    cmp qword [rbx + 56], 2
    jne .enter_read
    mov rdi, rbx
    call __al_stream_flush
    test eax, eax
    jnz .error
.enter_read:
    mov qword [rbx + 56], 1
    mov rax, [rbx + 72]
    cmp rax, -1
    je .next
    mov [r12], al
    mov qword [rbx + 72], -1
    inc r12
    inc r14
    dec r13
    jz .success
.next:
    mov rax, [rbx + 40]           ; cursor in the input buffer
    mov r15, [rbx + 48]
    sub r15, rax
    jz .need_input
    cmp r15, r13
    jbe .copy
    mov r15, r13
.copy:
    mov rsi, [rbx + 24]
    add rsi, rax
    mov rdi, r12
    mov rdx, r15
    call memcpy
    add [rbx + 40], r15
    add r12, r15
    add r14, r15
    sub r13, r15
    jnz .next
    jmp .success

.need_input:
    test qword [rbx + 8], 16      ; stay at EOF until cleared
    jnz .success
    mov rcx, [rbx + 32]           ; buffer capacity
    test rcx, rcx
    jz .direct
    xor edi, edi
    mov rsi, [rbx]
    mov rdx, [rbx + 24]
    call __al_stdio_io
    test rax, rax
    js .error
    jz .end_of_file
    mov qword [rbx + 40], 0
    mov [rbx + 48], rax
    jmp .next
.direct:
    xor edi, edi
    mov rsi, [rbx]
    mov rdx, r12
    mov rcx, r13
    call __al_stdio_io
    test rax, rax
    js .error
    jz .end_of_file
    add r12, rax
    add r14, rax
    sub r13, rax
    jnz .direct
    jmp .success
.end_of_file:
    or qword [rbx + 8], 16
.success:
    xor edx, edx
    jmp .done
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
