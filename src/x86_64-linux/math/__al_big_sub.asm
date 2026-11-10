; Original in-place unsigned subtraction with left >= right. rdi = left, rsi = right.
bits 64
default rel

global __al_big_sub:function

section .text.__al_big_sub alloc exec nowrite progbits
__al_big_sub:
    mov r10, [rdi]
    mov r11, [rsi]
    xor r8d, r8d
    xor r9d, r9d                 ; borrow
.next:
    cmp r8, r10
    jae .normalize
    mov eax, [rdi + r8*4 + 8]
    xor edx, edx
    cmp r8, r11
    jae .subtract
    mov edx, [rsi + r8*4 + 8]
.subtract:
    add rdx, r9
    sub rax, rdx
    mov [rdi + r8*4 + 8], eax
    shr rax, 63
    mov r9, rax
    inc r8
    jmp .next
.normalize:
    test r10, r10
    jz .done
    cmp dword [rdi + r10*4 + 4], 0
    jne .done
    dec r10
    jmp .normalize
.done:
    mov [rdi], r10
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
