; Normalize rsi/rdx at signed scale rcx to precision r8 into rdi.
bits 64
default rel

global __al_complex_scaled_ratio_precision:function
extern __al_big_bits:function
extern __al_big_left:function
extern __al_fixed_ratio_precision:function

section .text.__al_complex_scaled_ratio_precision alloc exec nowrite progbits
__al_complex_scaled_ratio_precision:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov [rsp], r8
    mov rdi, r12
    call __al_big_bits
    mov r15, rax
    mov rdi, r13
    call __al_big_bits
    sub r15, rax
    inc r15
    add r14, r15
    sub r14, [rsp]
    mov rsi, r15
    mov rdi, r13
    test rsi, rsi
    jns .shift
    neg rsi
    mov rdi, r12
.shift:
    call __al_big_left
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    mov rcx, [rsp]
    call __al_fixed_ratio_precision
    mov rax, r14
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
