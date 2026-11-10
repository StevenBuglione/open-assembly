; Original spawn handshake. rdi = prepared workspace. Returns a positive
; error or zero, and publishes the child PID only after an empty EOF.
bits 64
default rel

global __al_spawn_run:function
extern __al_syscall:function
extern __al_spawn_reserve:function
extern __al_spawn_child:function
extern __al_spawn_reap:function
extern close:function
extern kill:function

section .text.__al_spawn_run alloc exec nowrite progbits
__al_spawn_run:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 16
    mov rbx, rdi
    mov qword [rsp], 0
    mov edi, 293                  ; __NR_pipe2
    lea rsi, [rbx + 48]
    mov edx, 0x80000              ; O_CLOEXEC on both ends
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .raw_error
    mov rdi, rbx
    call __al_spawn_reserve
    cmp rax, -4095
    jae .before_fork_error

    mov qword [rbx + 72], -1     ; block signals across fork and child setup
    mov edi, 14                   ; __NR_rt_sigprocmask
    mov esi, 2                    ; SIG_SETMASK
    lea rdx, [rbx + 72]
    lea rcx, [rbx + 64]           ; original parent mask
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .before_fork_error
    mov edi, 57                   ; __NR_fork
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jz .child
    mov r12, rax                  ; parent pid result or fork error

    mov edi, 14                   ; __NR_rt_sigprocmask
    mov esi, 2
    lea rdx, [rbx + 64]
    xor ecx, ecx
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .restore_failed
    cmp r12, -4095
    jae .fork_failed
    movsxd rdi, dword [rbx + 52]
    call close                    ; parent no longer owns a write end
    xor r14d, r14d               ; bytes received
.read:
    mov edi, 0                    ; __NR_read
    movsxd rsi, dword [rbx + 48]
    lea rdx, [rbx + r14 + 88]
    mov ecx, 4
    sub rcx, r14
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4                   ; EINTR
    je .read
    cmp rax, -4095
    jae .read_failed
    test rax, rax
    jz .eof
    add r14, rax
    cmp r14, 4
    jb .read
    ja .protocol_error
    mov r13d, [rbx + 88]
    test r13d, r13d
    jz .protocol_error
    cmp r13d, 4095
    ja .protocol_error
    jmp .reap_error
.eof:
    test r14, r14
    jnz .protocol_error
    movsxd rdi, dword [rbx + 48]
    call close
    mov rax, [rbx + 40]
    test rax, rax
    jz .success
    mov [rax], r12d              ; publish only after successful exec handshake
.success:
    xor eax, eax
    jmp .done
.read_failed:
    neg eax
    mov r13d, eax
    jmp .stop_child
.protocol_error:
    mov r13d, 5                   ; EIO for a broken error message
.stop_child:
    mov rdi, r12
    mov esi, 9                    ; SIGKILL
    call kill
.reap_error:
    movsxd rdi, dword [rbx + 48]
    call close
    mov rdi, r12
    call __al_spawn_reap
    mov eax, r13d
    jmp .done
.restore_failed:
    mov r13, rax
    cmp r12, -4095
    jae .close_pipe
    mov rdi, r12
    mov esi, 9
    call kill
    mov rdi, r12
    call __al_spawn_reap
    jmp .close_pipe
.fork_failed:
    mov r13, r12
    jmp .close_pipe
.before_fork_error:
    mov r13, rax
.close_pipe:
    movsxd rdi, dword [rbx + 48]
    call close
    movsxd rdi, dword [rbx + 52]
    call close
    mov rax, r13
.raw_error:
    neg eax
.done:
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.child:
    mov rdi, rbx
    call __al_spawn_child
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
