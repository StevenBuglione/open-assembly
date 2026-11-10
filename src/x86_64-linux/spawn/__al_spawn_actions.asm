; Original ordered child actions. rdi = first action. Returns raw kernel status.
bits 64
default rel

global __al_spawn_actions:function
extern __al_syscall:function
extern __al_fcntl:function
extern close:function

section .text.__al_spawn_actions alloc exec nowrite progbits
__al_spawn_actions:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 16
    mov rbx, rdi
    mov qword [rsp], 0
.next:
    test rbx, rbx
    jz .success
    movsxd r12, dword [rbx + 12]
    mov eax, [rbx + 8]
    test eax, eax
    jz .close
    cmp eax, 1
    je .dup
    cmp eax, 2
    je .open
    mov rax, -22                 ; invalid internal action
    jmp .done
.close:
    mov edi, 3                   ; __NR_close
    mov rsi, r12
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    jmp .check
.dup:
    movsxd r13, dword [rbx + 16]
    cmp r12, r13
    je .same_fd
    mov edi, 33                  ; __NR_dup2
    mov rsi, r12
    mov rdx, r13
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    jmp .check
.same_fd:
    mov rdi, r12
    mov esi, 1                   ; F_GETFD validates the source
    xor edx, edx
    call __al_fcntl
    cmp rax, -4095
    jae .done
    mov edx, eax
    and edx, -2                  ; clear FD_CLOEXEC for same-fd duplication
    mov rdi, r12
    mov esi, 2                   ; F_SETFD
    call __al_fcntl
    jmp .check
.open:
    mov rdi, r12                 ; release the target before opening the path
    call close
    mov edi, 257                 ; __NR_openat
    mov rsi, -100                ; AT_FDCWD
    lea rdx, [rbx + 32]          ; copied pathname
    movsxd rcx, dword [rbx + 16]
    mov r8d, [rbx + 20]
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .done
    cmp rax, r12
    je .advance
    mov r13, rax
    mov rsi, rax
    mov edi, 33                  ; __NR_dup2
    mov rdx, r12
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov r14, rax
    mov rdi, r13
    call close
    mov rax, r14
    cmp rax, -4095
    jae .done
    test dword [rbx + 16], 0x80000 ; O_CLOEXEC requested for this open
    jz .advance
    mov rdi, r12
    mov esi, 2
    mov edx, 1
    call __al_fcntl
.check:
    cmp rax, -4095
    jae .done
.advance:
    mov rbx, [rbx]
    jmp .next
.success:
    xor eax, eax
.done:
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
