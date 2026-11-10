; Return sqrt(x²+y²)-x using offset rsi/rdx and y² rcx/r8; result bignum rdi.
bits 64
default rel

global __al_complex_distance_delta:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_copy:function
extern __al_big_multiply:function
extern __al_complex_scaled_add:function
extern __al_complex_scaled_sqrt:function
extern __al_complex_scaled_ratio:function

section .text.__al_complex_distance_delta alloc exec nowrite progbits
__al_complex_distance_delta:
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
    mov r15, r8
    cmp qword [r14], 0
    je .zero
    lea rdi, [rel distance_lock]
    call __al_lock
    lea rdi, [rel radicand]
    mov rsi, r12
    mov rdx, r12
    call __al_big_multiply
    lea rdi, [rel auxiliary]
    mov rsi, r14
    call __al_big_copy
    lea rdi, [rel radicand]
    lea rsi, [rel auxiliary]
    lea rdx, [r13 + r13]
    mov rcx, r15
    call __al_complex_scaled_add
    lea rdi, [rel radius]
    lea rsi, [rel radicand]
    mov rdx, rax
    lea rcx, [rel remainder]
    lea r8, [rel trial]
    call __al_complex_scaled_sqrt
    mov [rsp], rax
    lea rdi, [rel auxiliary]
    mov rsi, r12
    call __al_big_copy
    lea rdi, [rel radius]
    lea rsi, [rel auxiliary]
    mov rdx, [rsp]
    mov rcx, r13
    call __al_complex_scaled_add
    sub r15, rax
    lea rdi, [rel auxiliary]
    mov rsi, r14
    call __al_big_copy
    mov rdi, rbx
    lea rsi, [rel auxiliary]
    lea rdx, [rel radius]
    mov rcx, r15
    call __al_complex_scaled_ratio
    mov rbx, rax
    lea rdi, [rel distance_lock]
    call __al_unlock
    mov rax, rbx
    jmp .done
.zero:
    mov qword [rbx], 0
    xor eax, eax
.done:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss alloc noexec write nobits
alignb 16
distance_lock: resd 1
alignb 16
radicand: resb 10248
auxiliary: resb 10248
radius: resb 10248
remainder: resb 10248
trial: resb 10248

section .note.GNU-stack noalloc noexec nowrite progbits
