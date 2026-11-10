; Compare squares of dyadics rdi/rsi and rdx/rcx. r8 selects left/right factor three.
bits 64
default rel

global __al_complex_square_cmp:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_mul_u64:function
extern __al_big_copy:function
extern __al_complex_align:function
extern __al_big_cmp:function

section .text.__al_complex_square_cmp alloc exec nowrite progbits
__al_complex_square_cmp:
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
    mov r15d, r8d
    lea rdi, [rel square_lock]
    call __al_lock
    mov rax, rbx
    mul rbx
    mov rsi, rax
    lea rdi, [rel left_square]
    call __al_big_init128
    mov rax, r13
    mul r13
    mov rsi, rax
    lea rdi, [rel right_square]
    call __al_big_init128
    test r15d, r15d
    jz .align
    lea rbx, [rel left_square]
    cmp r15d, 1
    je .multiply
    lea rbx, [rel right_square]
.multiply:
    lea rdi, [rel triple]
    mov rsi, rbx
    mov edx, 3
    call __al_big_mul_u64
    mov rdi, rbx
    lea rsi, [rel triple]
    call __al_big_copy
.align:
    lea rdi, [rel left_square]
    lea rsi, [rel right_square]
    lea rdx, [r12 + r12]
    lea rcx, [r14 + r14]
    call __al_complex_align
    lea rdi, [rel left_square]
    lea rsi, [rel right_square]
    call __al_big_cmp
    mov ebx, eax
    lea rdi, [rel square_lock]
    call __al_unlock
    mov eax, ebx
    add rsp, 0
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss alloc noexec write nobits
alignb 16
square_lock: resd 1
alignb 16
left_square: resb 10248
right_square: resb 10248
triple: resb 32

section .note.GNU-stack noalloc noexec nowrite progbits
