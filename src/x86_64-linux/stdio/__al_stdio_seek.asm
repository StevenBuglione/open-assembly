; Original lseek wrapper. rdi = fd, rsi = offset, rdx = origin.
bits 64
default rel

global __al_stdio_seek:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.__al_stdio_seek alloc exec nowrite progbits
__al_stdio_seek:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 8                    ; __NR_lseek
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
