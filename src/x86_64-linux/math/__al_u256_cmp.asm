; Compare two unsigned little-endian four-qword values at rdi and rsi.
bits 64
default rel

global __al_u256_cmp:function

section .text.__al_u256_cmp alloc exec nowrite progbits
__al_u256_cmp:
    mov ecx, 4
.next:
    dec ecx
    mov rax, [rdi + rcx*8]
    cmp rax, [rsi + rcx*8]
    ja .greater
    jb .less
    test ecx, ecx
    jnz .next
    xor eax, eax
    ret
.greater:
    mov eax, 1
    ret
.less:
    mov eax, -1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
