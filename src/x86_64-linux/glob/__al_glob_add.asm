; Add a copied path to the owned result vector. Keep prior entries on failure.
; RDI context, RSI path. Return zero or GLOB_NOSPACE.
bits 64
default rel

global __al_glob_add:function
extern __errno_location:function
extern calloc:function
extern realloc:function
extern strdup:function
extern free:function

section .text.__al_glob_add alloc exec nowrite progbits
__al_glob_add:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, [rbx]
    mov r13, [r12]
    add r13, [r12 + 16]         ; destination slot
    jc .overflow
    mov r14, r13
    add r14, 2                  ; appended path and terminal null
    jc .overflow
    mov rax, r14
    shr rax, 61
    jnz .overflow
    mov rdi, rsi
    call strdup
    test rax, rax
    jz .no_space
    mov r15, rax
    mov rax, [r12 + 8]
    cmp r14, [rbx + 40]
    jbe .store
    mov rax, [rbx + 40]
    add rax, rax
    mov rdx, rax
    shr rdx, 61
    jnz .save_capacity
    cmp rax, 8
    jae .test_growth
    mov eax, 8
.test_growth:
    cmp rax, r14
    jb .save_capacity
    mov r14, rax
.save_capacity:
    mov rdi, [r12 + 8]
    test rdi, rdi
    jz .first_vector
    lea rsi, [r14 * 8]
    call realloc
    jmp .allocated
.first_vector:
    mov rdi, r14
    mov esi, 8
    call calloc
.allocated:
    test rax, rax
    jz .drop_copy
    mov [r12 + 8], rax
    mov [rbx + 40], r14
.store:
    mov [rax + r13 * 8], r15
    mov qword [rax + r13 * 8 + 8], 0
    inc qword [r12]
    xor eax, eax
    jmp .return
.drop_copy:
    mov rdi, r15
    call free
    jmp .no_space
.overflow:
    call __errno_location
    mov dword [rax], 12         ; ENOMEM
.no_space:
    mov eax, 1                 ; GLOB_NOSPACE
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
