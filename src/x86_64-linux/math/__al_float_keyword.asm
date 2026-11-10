; Original ASCII case-insensitive token match. Returns the input pointer
; after the keyword, or NULL. rdi = input, rsi = ASCII keyword, rdx = stride.
bits 64
default rel

global __al_float_keyword:function

section .text.__al_float_keyword alloc exec nowrite progbits
__al_float_keyword:
    mov rax, rdi
    mov r8, rdx
.next:
    movzx edx, byte [rsi]
    test edx, edx
    jz .done
    cmp r8d, 4
    je .wide_unit
    movzx ecx, byte [rax]
    jmp .unit
.wide_unit:
    mov ecx, [rax]
.unit:
    or ecx, 32
    cmp ecx, edx
    jne .missing
    add rax, r8
    inc rsi
    jmp .next
.missing:
    xor eax, eax
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
