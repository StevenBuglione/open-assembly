; Multiply bignum rsi by a 64-bit factor in rdx into distinct bignum rdi.
bits 64
default rel

global __al_big_mul_u64:function
extern __al_big_bad:function

section .text.__al_big_mul_u64 alloc exec nowrite progbits
__al_big_mul_u64:
    push rbx
    mov rbx, rdx
    mov r11, [rsi]
    test rbx, rbx
    jz .zero
    test r11, r11
    jz .zero
    xor ecx, ecx
    xor r8d, r8d
.multiply:
    mov eax, [rsi + rcx*4 + 8]
    mul rbx
    add rax, r8
    adc rdx, 0
    mov [rdi + rcx*4 + 8], eax
    shr rax, 32
    shl rdx, 32
    or rax, rdx
    mov r8, rax
    inc rcx
    cmp rcx, r11
    jb .multiply
    test r8, r8
    jz .count
    cmp rcx, 2560
    jae .capacity
    mov [rdi + rcx*4 + 8], r8d
    inc rcx
    shr r8, 32
    jz .count
    cmp rcx, 2560
    jae .capacity
    mov [rdi + rcx*4 + 8], r8d
    inc rcx
.count:
    mov [rdi], rcx
    pop rbx
    ret
.zero:
    xor ecx, ecx
    jmp .count
.capacity:
    call __al_big_bad

section .note.GNU-stack noalloc noexec nowrite progbits
