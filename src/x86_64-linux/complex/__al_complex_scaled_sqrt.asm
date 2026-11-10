; Square root rsi at exponent rdx into rdi, with scratch at rcx/r8. Return result power.
bits 64
default rel

global __al_complex_scaled_sqrt:function
extern __al_big_bits:function
extern __al_big_left:function
extern __al_big_right_sticky:function
extern __al_big_isqrt:function

section .text.__al_complex_scaled_sqrt alloc exec nowrite progbits
__al_complex_scaled_sqrt:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8
    mov rdi, r12
    call __al_big_bits
    test rax, rax
    jz .zero
    lea rax, [rax + r13 - 1]
    sar rax, 1
    sub rax, 256
    mov rsi, rax
    add rsi, rsi
    sub r13, rsi
    mov rsi, r13
    mov r13, rax
    mov rdi, r12
    test rsi, rsi
    js .right
    call __al_big_left
    jmp .root
.right:
    neg rsi
    call __al_big_right_sticky
.root:
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r14
    mov rcx, r15
    call __al_big_isqrt
    mov rax, r13
    jmp .done
.zero:
    mov qword [rbx], 0
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
