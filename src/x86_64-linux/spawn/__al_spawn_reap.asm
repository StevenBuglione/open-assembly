; Original wait for a failed child. rdi = child pid. Retry EINTR and return raw status.
bits 64
default rel

global __al_spawn_reap:function
extern __al_syscall:function

section .text.__al_spawn_reap alloc exec nowrite progbits
__al_spawn_reap:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rdi
    mov qword [rsp], 0
.retry:
    mov edi, 61                  ; __NR_wait4
    mov rsi, rbx
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4                  ; EINTR
    je .retry
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
