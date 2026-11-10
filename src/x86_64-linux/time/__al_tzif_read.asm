; Original bounded read of a regular TZif file. Return bytes and length in
; RAX/RDX, or null on failure. O_NONBLOCK avoids waiting on invalid file types.
bits 64
default rel

global __al_tzif_read:function
extern __al_syscall:function
extern close:function
extern malloc:function
extern free:function

section .text.__al_tzif_read alloc exec nowrite progbits
__al_tzif_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 152
    mov qword [rsp], 0
    mov rbx, rdi
.open:
    mov rdx, rbx
    mov edi, 257                 ; __NR_openat
    mov rsi, -100                ; AT_FDCWD
    mov ecx, 0x80800             ; O_RDONLY | O_NONBLOCK | O_CLOEXEC
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4
    je .open
    cmp rax, -4095
    jae .failure
    mov r12, rax
    xor r13d, r13d
.stat:
    mov edi, 5                   ; __NR_fstat
    mov rsi, r12
    lea rdx, [rsp + 8]
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4
    je .stat
    test rax, rax
    jnz .close_error
    mov eax, [rsp + 32]          ; st_mode
    and eax, 0xf000
    cmp eax, 0x8000              ; S_IFREG
    jne .close_error
    mov r14, [rsp + 56]          ; st_size
    cmp r14, 44
    jb .close_error
    cmp r14, 1048576
    ja .close_error
    mov rdi, r14
    call malloc
    test rax, rax
    jz .close_error
    mov r13, rax
    xor ebx, ebx
.read:
    xor edi, edi                 ; __NR_read
    mov rsi, r12
    lea rdx, [r13 + rbx]
    mov r15, r14
    sub r15, rbx
    mov rcx, r15
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4
    je .read
    test rax, rax
    jle .close_error
    cmp rax, r15
    ja .close_error
    add rbx, rax
    cmp rbx, r14
    jb .read
    mov rdi, r12
    call close
    mov rax, r13
    mov rdx, r14
    jmp .done
.close_error:
    mov rdi, r12
    call close
    mov rdi, r13
    call free
.failure:
    xor eax, eax
    xor edx, edx
.done:
    add rsp, 152
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
