; Test-only deliberately distinct strlen for the same-symbol similarity control.
bits 64
default rel

global strlen:function
section .text.strlen alloc exec nowrite progbits
strlen:
    mov rdx, rdi
    xor eax, eax
    cmp byte [rdi], 0
    je .empty
    lea rdi, [rdi + 1]
    xor ecx, ecx
    not rcx
    cld
    repne scasb
    lea rax, [rdi - 1]
    sub rax, rdx
    ret
.empty:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
