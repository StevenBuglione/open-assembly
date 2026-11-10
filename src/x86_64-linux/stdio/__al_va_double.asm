; Original SysV binary64 va_arg. rdi = va_list, rax = raw double bits.
bits 64
default rel

global __al_va_double:function

section .text.__al_va_double alloc exec nowrite progbits
__al_va_double:
    mov eax, [rdi + 4]
    cmp eax, 176
    jae .stack
    mov rdx, [rdi + 16]
    mov rax, [rdx + rax]
    add dword [rdi + 4], 16
    ret
.stack:
    mov rdx, [rdi + 8]
    mov rax, [rdx]
    add rdx, 8
    mov [rdi + 8], rdx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
