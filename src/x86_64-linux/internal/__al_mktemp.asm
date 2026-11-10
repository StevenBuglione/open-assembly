; Original exclusive temporary file creation. rdi = mutable template,
; rsi = optional extra open flags. Returns the descriptor or -1 and errno.
bits 64
default rel

global __al_mktemp:function
extern strlen:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.__al_mktemp alloc exec nowrite progbits
__al_mktemp:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 16
    mov rbx, rdi
    mov r13, rsi
    test rbx, rbx
    jz .invalid
    call strlen
    cmp rax, 6
    jb .invalid
    lea r12, [rbx + rax - 6]
    cmp dword [r12], 0x58585858
    jne .invalid
    cmp word [r12 + 4], 0x5858
    jne .invalid
    mov r14d, 256                 ; collision limit
.random:
    mov qword [rsp], 0
    xor ecx, ecx                  ; blocking urandom source
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 318                  ; __NR_getrandom
    mov edx, 8
    lea rsi, [rsp + 8]
    call __al_syscall
    cmp rax, 8
    je .name
    cmp rax, -4                   ; EINTR before entropy initialization
    je .random
    cmp rax, -4095
    jae .failed_name
    mov rax, -5                   ; an initialized eight-byte request is exact
    jmp .failed_name
.name:
    mov rax, [rsp + 8]
    mov r9d, 62
    xor ecx, ecx
    lea r8, [rel alphabet]
.digit:
    xor edx, edx
    div r9
    mov dl, [r8 + rdx]
    mov [r12 + rcx], dl
    inc ecx
    cmp ecx, 6
    jb .digit

    mov edi, 257                  ; __NR_openat
    mov rsi, -100                 ; AT_FDCWD
    mov rdx, rbx
    mov rcx, r13
    or ecx, 194                   ; O_RDWR | O_CREAT | O_EXCL
    mov r8d, 384                  ; 0600
    xor r9d, r9d
    call __al_syscall
    cmp rax, -17                  ; EEXIST
    je .collision
    cmp rax, -4095
    jae .failed_name
    jmp .done
.collision:
    dec r14d
    jnz .random
.failed_name:
    mov dword [r12], 0x58585858
    mov word [r12 + 4], 0x5858
    jmp .error
.invalid:
    mov rax, -22                  ; EINVAL
.error:
    mov rdi, rax
    call __al_syscall_result
.done:
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_mktemp alloc noexec nowrite progbits
alphabet:
    db 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

section .note.GNU-stack noalloc noexec nowrite progbits
