; Original scanner lookahead. rdi = source context. Returns a byte or -1.
bits 64
default rel

global __al_scan_peek:function
extern __al_stream_read:function

section .text.__al_scan_peek alloc exec nowrite progbits
__al_scan_peek:
    mov rax, [rdi + 24]
    cmp rax, -2
    jne .done
    cmp qword [rdi + 8], 0
    jne .file
    mov rax, [rdi]
    movzx eax, byte [rax]
    test eax, eax
    jnz .remember
    mov rax, -1
.remember:
    mov [rdi + 24], rax
.done:
    ret
.file:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rdi
    mov rdi, [rbx]
    lea rsi, [rbx + 32]
    mov edx, 1
    call __al_stream_read
    test rax, rax
    jz .end
    movzx eax, byte [rbx + 32]
    jmp .cache
.end:
    mov rax, -1
.cache:
    mov [rbx + 24], rax
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
