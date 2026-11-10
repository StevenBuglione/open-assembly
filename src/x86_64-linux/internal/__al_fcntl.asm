; Original raw descriptor control. rdi = fd, rsi = command, rdx = argument.
bits 64
default rel

global __al_fcntl:function
extern __al_syscall:function

section .text.__al_fcntl alloc exec nowrite progbits
__al_fcntl:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 72                   ; __NR_fcntl
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
