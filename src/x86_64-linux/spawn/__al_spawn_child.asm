; Original fork-child path. rdi = prepared workspace. No allocation or stdio.
bits 64
default rel

global __al_spawn_child:function
extern __al_syscall:function
extern __al_spawn_attrs:function
extern __al_spawn_actions:function
extern __al_exec_search:function
extern __al_execve_raw:function
extern close:function
extern _exit:function

section .text.__al_spawn_child alloc exec nowrite progbits
__al_spawn_child:
    push rbp
    mov rbp, rsp
    push rbx
    push r13
    sub rsp, 16
    mov rbx, rdi
    mov qword [rsp], 0
    movsxd rdi, dword [rbx + 48]
    call close                    ; child owns only the handshake write end
    mov rdi, rbx
    call __al_spawn_attrs
    cmp rax, -4095
    jae .error
    mov rdi, [rbx + 24]
    call __al_spawn_actions
    cmp rax, -4095
    jae .error

    mov edi, 14                   ; __NR_rt_sigprocmask
    mov esi, 2                    ; SIG_SETMASK
    lea rdx, [rbx + 80]
    xor ecx, ecx
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .error
    mov rdi, [rbx]
    mov rsi, [rbx + 8]
    mov rdx, [rbx + 16]
    mov rcx, [rbx + 56]
    test rcx, rcx
    jz .explicit_path
    lea r8, [rbx + 128]
    xor r9d, r9d                  ; report ENOEXEC without shell fallback
    call __al_exec_search
    jmp .exec_return
.explicit_path:
    call __al_execve_raw
.exec_return:
    cmp rax, -4095
    jae .error
    mov rax, -5                   ; an exec success cannot return
.error:
    neg eax
    mov [rbx + 88], eax
    xor r13d, r13d
.write:
    mov edi, 1                    ; __NR_write
    movsxd rsi, dword [rbx + 52]
    lea rdx, [rbx + r13 + 88]
    mov ecx, 4
    sub rcx, r13
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4                   ; EINTR
    je .write
    test rax, rax
    jle .exit
    add r13, rax
    cmp r13, 4
    jb .write
.exit:
    mov edi, 127
    call _exit
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
