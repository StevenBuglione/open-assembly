; Multiply rsi/rdx at rcx fractional bits into rdi using distinct scratch at r8.
bits 64
default rel

global __al_fixed_mul_precision:function
extern __al_big_multiply:function
extern __al_big_right_sticky:function
extern __al_big_copy:function

section .text.__al_fixed_mul_precision alloc exec nowrite progbits
__al_fixed_mul_precision:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rcx
    mov r13, r8
    mov rdi, r13
    call __al_big_multiply
    mov rdi, r13
    mov rsi, r12
    call __al_big_right_sticky
    mov rdi, rbx
    mov rsi, r13
    call __al_big_copy
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
