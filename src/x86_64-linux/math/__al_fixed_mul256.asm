; Multiply normalized Q256 operands at rsi/rdx into rdi using 18 dwords at rcx. Inputs have at most nine limbs.
bits 64
default rel

global __al_fixed_mul256:function

section .text.__al_fixed_mul256 alloc exec nowrite progbits
__al_fixed_mul256:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, [rsi]
    mov r12, [rdx]
    mov r13, rcx
    mov r14, rsi
    mov r15, rdx
    xor r8d, r8d
.clear:
    mov dword [r13 + r8*4], 0
    inc r8
    cmp r8, 18
    jb .clear

    xor r8d, r8d
.row:
    cmp r8, rbx
    jae .product
    xor r9d, r9d
    xor r10d, r10d
.column:
    lea r11, [r8 + r9]
    cmp r9, r12
    je .carry
    mov eax, [r14 + r8*4 + 8]
    mov esi, [r15 + r9*4 + 8]
    imul rax, rsi
    mov esi, [r13 + r11*4]
    add rax, rsi
    add rax, r10
    mov [r13 + r11*4], eax
    shr rax, 32
    mov r10, rax
    inc r9
    jmp .column
.carry:
    mov [r13 + r11*4], r10d
    inc r8
    jmp .row
.product:
    mov r8d, 10
.normalize:
    test r8, r8
    jz .size
    cmp dword [r13 + r8*4 + 28], 0
    jne .size
    dec r8
    jmp .normalize
.size:
    mov [rdi], r8
    xor ecx, ecx
.copy:
    cmp rcx, r8
    je .done
    mov eax, [r13 + rcx*4 + 32]
    mov [rdi + rcx*4 + 8], eax
    inc rcx
    jmp .copy
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
