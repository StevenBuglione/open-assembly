; Original byte transfer. rdi = syscall 0/read or 1/write, rsi = fd,
; rdx = buffer and rcx = size. Retry EINTR and translate a final error.
bits 64
default rel

global __al_stdio_io:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.__al_stdio_io alloc exec nowrite progbits
__al_stdio_io:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 16
    mov qword [rsp], 0
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
.retry:
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    mov rcx, r14
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4                    ; EINTR
    je .retry
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
