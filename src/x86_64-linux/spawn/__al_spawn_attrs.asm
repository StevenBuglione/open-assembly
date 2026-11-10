; Original child attribute setup. rdi = spawn workspace with signals blocked.
; Returns raw Linux status and stores the final child mask at byte 80.
bits 64
default rel

global __al_spawn_attrs:function
extern __al_syscall:function

section .text.__al_spawn_attrs alloc exec nowrite progbits
__al_spawn_attrs:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    mov qword [rsp], 0
    mov rax, [rbx + 64]
    mov [rbx + 80], rax          ; retain the inherited mask by default
    mov r12, [rbx + 32]
    xor r15d, r15d               ; explicit default-disposition mask
    test r12, r12
    jz .signals_begin
    movzx r13d, word [r12 + 16]
    test r13d, 8                 ; POSIX_SPAWN_SETSIGMASK
    jz .defaults
    mov rax, [r12]
    mov [rbx + 80], rax
.defaults:
    test r13d, 4                 ; POSIX_SPAWN_SETSIGDEF
    jz .group
    mov r15, [r12 + 8]
.group:
    test r13d, 2                 ; POSIX_SPAWN_SETPGROUP
    jz .ids
    mov edi, 109                 ; __NR_setpgid
    xor esi, esi
    movsxd rdx, dword [r12 + 20]
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .done
.ids:
    test r13d, 1                 ; POSIX_SPAWN_RESETIDS
    jz .signals_begin
    mov edi, 104                 ; __NR_getgid
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .done
    mov rdx, rax
    mov edi, 119                 ; __NR_setresgid
    mov rsi, -1
    mov rcx, -1
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .done
    mov edi, 102                 ; __NR_getuid
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .done
    mov rdx, rax
    mov edi, 117                 ; __NR_setresuid
    mov rsi, -1
    mov rcx, -1
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .done
.signals_begin:
    mov r14d, 1
.signal:
    cmp r14d, 9                  ; SIGKILL cannot have a disposition
    je .advance
    cmp r14d, 19                 ; SIGSTOP cannot have a disposition
    je .advance
    mov edi, 13                  ; __NR_rt_sigaction
    mov esi, r14d
    xor edx, edx
    lea rcx, [rbx + 96]          ; kernel action scratch
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .done
    cmp qword [rbx + 96], 1      ; default or ignored
    ja .reset                    ; clear inherited caught handlers before unblocking
    test r15b, 1
    jz .advance
.reset:
    mov edi, 13                  ; __NR_rt_sigaction
    mov esi, r14d
    lea rdx, [rel default_action]
    xor ecx, ecx
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .done
.advance:
    shr r15, 1
    inc r14d
    cmp r14d, 64
    jbe .signal
    xor eax, eax
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_spawn_attrs alloc noexec nowrite progbits align=8
default_action:
    dq 0, 0, 0, 0

section .note.GNU-stack noalloc noexec nowrite progbits
