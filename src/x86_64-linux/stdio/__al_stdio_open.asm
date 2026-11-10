; Original openat wrapper for C modes. rdi = path, rsi = mode.
; Returns fd or -1 in rax and stream access bits in rdx on success.
bits 64
default rel

global __al_stdio_open:function
extern __al_syscall:function
extern __al_syscall_result:function
extern __al_stdio_errno:function

section .text.__al_stdio_open alloc exec nowrite progbits
__al_stdio_open:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 16
    mov qword [rsp], 0
    mov rbx, rdi
    test rdi, rdi
    jz .invalid
    test rsi, rsi
    jz .invalid
    movzx eax, byte [rsi]
    cmp eax, 114                  ; r
    je .read_mode
    cmp eax, 119                  ; w
    je .write_mode
    cmp eax, 97                   ; a
    jne .invalid
    mov r12d, 1089                ; O_WRONLY | O_CREAT | O_APPEND
    mov r13d, 6                   ; writable, append
    jmp .options
.read_mode:
    xor r12d, r12d                ; O_RDONLY
    mov r13d, 1                   ; readable
    jmp .options
.write_mode:
    mov r12d, 577                 ; O_WRONLY | O_CREAT | O_TRUNC
    mov r13d, 2                   ; writable
.options:
    xor r14d, r14d                ; options already seen
.next:
    inc rsi
    movzx eax, byte [rsi]
    test eax, eax
    jz .open
    cmp eax, 98                   ; b
    je .binary
    cmp eax, 43                   ; +
    je .update
    cmp eax, 120                  ; x
    jne .invalid
    test r12d, 512                ; exclusive creation is valid for w modes
    jz .invalid
    test r14d, 4
    jnz .invalid
    or r14d, 4
    or r12d, 128                  ; O_EXCL
    jmp .next
.binary:
    test r14d, 1
    jnz .invalid
    or r14d, 1
    jmp .next
.update:
    test r14d, 2
    jnz .invalid
    or r14d, 2
    and r12d, -4
    or r12d, 2                    ; O_RDWR
    or r13d, 3
    jmp .next
.open:
    mov edi, 257                  ; __NR_openat
    mov rsi, -100                 ; AT_FDCWD
    mov rdx, rbx
    mov rcx, r12
    mov r8d, 438                  ; 0666, filtered by the process umask
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    mov rdx, r13
    jmp .done
.invalid:
    mov edi, 22                   ; EINVAL
    call __al_stdio_errno
.done:
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
