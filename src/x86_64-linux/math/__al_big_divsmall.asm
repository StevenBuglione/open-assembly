; Original in-place division by a positive 32-bit divisor. Return remainder.
bits 64
default rel

global __al_big_divsmall:function

section .text.__al_big_divsmall alloc exec nowrite progbits
__al_big_divsmall:
    mov rcx, [rdi]
    xor edx, edx
    test rcx, rcx
    jz .done
.next:
    dec rcx
    mov rax, rdx
    shl rax, 32
    mov edx, [rdi + rcx*4 + 8]
    or rax, rdx
    xor edx, edx
    div rsi
    mov [rdi + rcx*4 + 8], eax
    test rcx, rcx
    jnz .next
    mov rcx, [rdi]
.normalize:
    test rcx, rcx
    jz .store
    cmp dword [rdi + rcx*4 + 4], 0
    jne .store
    dec rcx
    jmp .normalize
.store:
    mov [rdi], rcx
.done:
    mov rax, rdx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
