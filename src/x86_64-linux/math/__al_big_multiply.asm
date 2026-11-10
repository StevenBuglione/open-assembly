; Multiply distinct nonnegative bignums at rsi and rdx into rdi.
bits 64
default rel

global __al_big_multiply:function
extern __al_big_bad:function

section .text.__al_big_multiply alloc exec nowrite progbits
__al_big_multiply:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r15, rdi
    mov r13, rsi
    mov r14, rdx
    mov rbx, [rsi]
    mov r12, [rdx]
    test rbx, rbx
    jz .zero
    test r12, r12
    jz .zero
    lea rcx, [rbx + r12]
    cmp rcx, 2560
    ja .capacity
    xor r8d, r8d
.clear:
    mov dword [r15 + r8*4 + 8], 0
    inc r8
    cmp r8, rcx
    jb .clear

    xor r8d, r8d
.row:
    xor r9d, r9d
    xor r10d, r10d
.column:
    lea r11, [r8 + r9]
    cmp r9, r12
    je .carry
    mov eax, [r13 + r8*4 + 8]
    mov esi, [r14 + r9*4 + 8]
    imul rax, rsi
    mov esi, [r15 + r11*4 + 8]
    add rax, rsi
    add rax, r10
    mov [r15 + r11*4 + 8], eax
    shr rax, 32
    mov r10, rax
    inc r9
    jmp .column
.carry:
    mov [r15 + r11*4 + 8], r10d
    inc r8
    cmp r8, rbx
    jb .row

    cmp dword [r15 + rcx*4 + 4], 0
    jne .size
    dec rcx
.size:
    mov [r15], rcx
    jmp .done
.zero:
    mov qword [r15], 0
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.capacity:
    call __al_big_bad

section .note.GNU-stack noalloc noexec nowrite progbits
