; Align bignums rdi/rsi at exponents rdx/rcx in place. Return the lower exponent.
bits 64
default rel

global __al_complex_align:function
extern __al_big_left:function

section .text.__al_complex_align alloc exec nowrite progbits
__al_complex_align:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov rsi, rdx
    sub rsi, rcx
    jz .return
    jg .shift
    neg rsi
    mov rdi, r12
    mov r14, r13
.shift:
    call __al_big_left
.return:
    mov rax, r14
    add rsp, 0
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
