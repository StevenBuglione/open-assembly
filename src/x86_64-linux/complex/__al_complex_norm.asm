; Compute exact squared norm at rdi with scratch at rsi, significands rdx/r8 and exponents rcx/r9.
bits 64
default rel

global __al_complex_norm:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_add:function

section .text.__al_complex_norm alloc exec nowrite progbits
__al_complex_norm:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, r8
    lea rax, [rcx + rcx]
    lea rdx, [r9 + r9]
    mov [rsp], rax
    mov [rsp + 8], rdx
    mov r15, rax
    cmp rax, rdx
    jle .scale
    mov r15, rdx
.scale:
    mov rax, r13
    mul rax
    mov rdi, rbx
    mov rsi, rax
    call __al_big_init128
    mov rdi, rbx
    mov rsi, [rsp]
    sub rsi, r15
    call __al_big_left
    mov rax, r14
    mul rax
    mov rdi, r12
    mov rsi, rax
    call __al_big_init128
    mov rdi, r12
    mov rsi, [rsp + 8]
    sub rsi, r15
    call __al_big_left
    mov rdi, rbx
    mov rsi, r12
    call __al_big_add
    mov rax, r15
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
