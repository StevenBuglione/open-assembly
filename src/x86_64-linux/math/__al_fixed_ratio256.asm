; Produce floor(2^256 * rsi / rcx:rdx) into bignum rdi. The denominator has at most 65 bits.
bits 64
default rel

global __al_fixed_ratio256:function

section .text.__al_fixed_ratio256 alloc exec nowrite progbits
__al_fixed_ratio256:
    push rbx
    push r12
    push r13
    mov r8, rsi
    xor r9d, r9d
    mov r10, rdx
    mov r11, rcx
    mov ebx, 8
.word:
    dec ebx
    mov r12d, 32
    xor r13d, r13d
.bit:
    add r8, r8
    adc r9, r9
    shl r13d, 1
    cmp r9, r11
    ja .subtract
    jb .next_bit
    cmp r8, r10
    jb .next_bit
.subtract:
    sub r8, r10
    sbb r9, r11
    or r13d, 1
.next_bit:
    dec r12d
    jnz .bit
    mov [rdi + rbx*4 + 8], r13d
    test ebx, ebx
    jnz .word
    mov ebx, 8
.normalize:
    test ebx, ebx
    jz .count
    cmp dword [rdi + rbx*4 + 4], 0
    jne .count
    dec ebx
    jmp .normalize
.count:
    mov [rdi], rbx
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
