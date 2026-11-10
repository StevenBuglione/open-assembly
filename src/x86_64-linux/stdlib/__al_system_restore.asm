; Original system signal restoration. rdi = saved workspace, rsi = setup
; stage count. Restore each saved item and return the first raw error.
bits 64
default rel

global __al_system_restore:function
extern __al_syscall:function

section .text.__al_system_restore alloc exec nowrite progbits
__al_system_restore:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    xor r13d, r13d
    test r12, r12
    jz .done
    mov qword [rsp], 0
    mov edi, 13                   ; __NR_rt_sigaction
    mov esi, 2                    ; SIGINT
    mov rdx, rbx
    xor ecx, ecx
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    mov r13, rax
    cmp r12, 2
    jb .done
    mov edi, 13                   ; __NR_rt_sigaction
    mov esi, 3                    ; SIGQUIT
    lea rdx, [rbx + 32]
    xor ecx, ecx
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    test r13, r13
    jnz .mask
    mov r13, rax
.mask:
    cmp r12, 3
    jb .done
    mov edi, 14                   ; __NR_rt_sigprocmask
    mov esi, 2                    ; SIG_SETMASK
    lea rdx, [rbx + 64]
    xor ecx, ecx
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    test r13, r13
    jnz .done
    mov r13, rax
.done:
    mov rax, r13
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
