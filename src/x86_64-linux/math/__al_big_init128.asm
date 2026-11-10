; Initialize the bignum at rdi from an unsigned 128-bit value (rsi low, rdx high).
bits 64
default rel

global __al_big_init128:function

section .text.__al_big_init128 alloc exec nowrite progbits
__al_big_init128:
    mov [rdi + 8], rsi
    mov [rdi + 16], rdx
    mov eax, 4
    mov rcx, rdx
    shr rcx, 32
    jnz .size
    dec eax
    test edx, edx
    jnz .size
    dec eax
    mov rcx, rsi
    shr rcx, 32
    jnz .size
    dec eax
    test esi, esi
    jnz .size
    xor eax, eax
.size:
    mov [rdi], rax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
