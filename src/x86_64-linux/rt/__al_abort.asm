; Original implementation. Fatal runtime errors bypass application handlers.
bits 64
default rel

global __al_abort:function
extern __al_syscall:function
extern _exit:function

section .text.__al_abort alloc exec nowrite progbits
__al_abort:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0

    mov edi, 13                    ; __NR_rt_sigaction
    mov esi, 6                     ; SIGABRT
    lea rdx, [rel default_action]
    xor ecx, ecx                   ; no previous action requested
    mov r8d, 8                     ; kernel sigset size
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jnz .fallback

    mov edi, 14                    ; __NR_rt_sigprocmask
    mov esi, 1                     ; SIG_UNBLOCK
    lea rdx, [rel sigabrt_mask]
    xor ecx, ecx
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jnz .fallback

    mov edi, 39                    ; __NR_getpid
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jle .fallback
    mov [rsp + 8], rax

    mov edi, 186                   ; __NR_gettid
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jle .fallback

    mov edi, 234                   ; __NR_tgkill
    mov rsi, [rsp + 8]
    mov rdx, rax
    mov ecx, 6                     ; SIGABRT
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall

.fallback:
    mov edi, 134
    call _exit
    ud2

section .rodata.__al_abort alloc noexec nowrite progbits align=8
default_action:
    dq 0, 0, 0, 0                 ; SIG_DFL, flags, restorer, mask
sigabrt_mask:
    dq 0x20                       ; 1 << (SIGABRT - 1)

section .note.GNU-stack noalloc noexec nowrite progbits
