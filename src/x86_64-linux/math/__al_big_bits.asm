; Original bit length of a normalized bignum. rdi = value.
bits 64
default rel

global __al_big_bits:function

section .text.__al_big_bits alloc exec nowrite progbits
__al_big_bits:
    xor eax, eax
    mov rdx, [rdi]
    test rdx, rdx
    jz .done
    dec rdx
    mov ecx, [rdi + rdx*4 + 8]
    mov rax, rdx
    shl rax, 5
.next:
    inc rax
    shr ecx, 1
    jnz .next
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
