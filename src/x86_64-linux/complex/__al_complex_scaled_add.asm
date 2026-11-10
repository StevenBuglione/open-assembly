; Add and normalize nonnegative bignums rdi/rsi at powers rdx/rcx. Return result power.
bits 64
default rel

global __al_complex_scaled_add:function
extern __al_complex_align:function
extern __al_big_add:function
extern __al_big_copy:function
extern __al_big_bits:function
extern __al_big_right_sticky:function

section .text.__al_complex_scaled_add alloc exec nowrite progbits
__al_complex_scaled_add:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    cmp qword [r12], 0
    je .result
    cmp qword [rbx], 0
    jne .align
    mov r13, rcx
    call __al_big_copy
    jmp .normalize
.align:
    call __al_complex_align
    mov r13, rax
    mov rdi, rbx
    mov rsi, r12
    call __al_big_add
.normalize:
    mov rdi, rbx
    call __al_big_bits
    sub rax, 320
    jle .result
    add r13, rax
    mov rdi, rbx
    mov rsi, rax
    call __al_big_right_sticky
.result:
    mov rax, r13
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
