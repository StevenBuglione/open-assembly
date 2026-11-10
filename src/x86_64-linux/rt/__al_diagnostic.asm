; Original implementation. Counted, best-effort stderr output for fatal paths.
bits 64
default rel

global __al_diagnostic:function
extern __al_syscall:function

section .text.__al_diagnostic alloc exec nowrite progbits
__al_diagnostic:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 16
    mov rbx, rdi                   ; bytes remaining to write
    mov r12, rsi                   ; number of remaining bytes
    test r12, r12
    jz .done

    ; A broken diagnostic pipe must not replace the intended fatal outcome.
    ; Only fatal callers use this helper, so the mask need not be restored.
    mov qword [rsp], 0
    mov edi, 14                    ; __NR_rt_sigprocmask
    xor esi, esi                   ; SIG_BLOCK
    lea rdx, [rel sigpipe_mask]
    xor ecx, ecx                   ; no output mask
    mov r8d, 8                     ; kernel sigset size
    xor r9d, r9d
    call __al_syscall

.write:
    mov edi, 1                     ; __NR_write
    mov esi, 2                     ; STDERR_FILENO
    mov rdx, rbx
    mov rcx, r12
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4                    ; EINTR before any bytes were written
    je .write
    test rax, rax
    jle .done
    add rbx, rax
    sub r12, rax
    jnz .write

.done:
    add rsp, 16
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_diagnostic alloc noexec nowrite progbits align=8
sigpipe_mask:
    dq 0x1000                     ; 1 << (SIGPIPE - 1)

section .note.GNU-stack noalloc noexec nowrite progbits
