; Original SysV AMD64 integer or pointer va_arg. rdi = va_list record.
bits 64
default rel

global __al_va_next:function

section .text.__al_va_next alloc exec nowrite progbits
__al_va_next:
    mov eax, [rdi]                ; gp_offset
    cmp eax, 48
    jae .stack
    mov rdx, [rdi + 16]           ; register save area
    mov rax, [rdx + rax]
    add dword [rdi], 8
    ret
.stack:
    mov rdx, [rdi + 8]            ; next stack argument
    mov rax, [rdx]
    add rdx, 8
    mov [rdi + 8], rdx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
