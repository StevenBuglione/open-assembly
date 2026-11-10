; Original locked stream association. rdi = FILE, rsi = fd, rdx = flags.
bits 64
default rel

global __al_stream_init:function
extern __al_streams:data
extern memset:function

section .text.__al_stream_init alloc exec nowrite progbits
__al_stream_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    xor esi, esi
    mov edx, 128
    call memset
    mov [rbx], r12
    mov [rbx + 8], r13
    mov rax, [rel __al_streams]
    mov [rbx + 16], rax
    mov [rel __al_streams], rbx
    lea rax, [rbx + 128]
    mov [rbx + 24], rax
    mov qword [rbx + 32], 4096
    mov qword [rbx + 72], -1
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
