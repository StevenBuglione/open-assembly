; Original Linux execve boundary. Returns only on failure, with raw errno.
bits 64
default rel

global __al_execve_raw:function
extern __al_syscall:function

section .text.__al_execve_raw alloc exec nowrite progbits
__al_execve_raw:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 59                  ; __NR_execve
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
