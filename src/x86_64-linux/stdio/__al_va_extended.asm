; Original SysV extended va_arg. rdi = va_list, rax = significand,
; dx = exponent/sign. Long double occupies one aligned 16-byte stack slot.
bits 64
default rel

global __al_va_extended:function

section .text.__al_va_extended alloc exec nowrite progbits
__al_va_extended:
    mov rdx, [rdi + 8]
    add rdx, 15
    and rdx, -16
    mov rax, [rdx]
    movzx ecx, word [rdx + 8]
    add rdx, 16
    mov [rdi + 8], rdx
    mov edx, ecx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
