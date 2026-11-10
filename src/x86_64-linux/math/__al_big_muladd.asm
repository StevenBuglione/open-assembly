; Original multiply by a small radix and add a digit. rdi = value, rsi = radix, rdx = digit.
bits 64
default rel

global __al_big_muladd:function
extern __al_big_bad:function

section .text.__al_big_muladd alloc exec nowrite progbits
__al_big_muladd:
    mov r11, [rdi]                ; normalized limb count
    mov r9, rdx                   ; carry from the prior limb
    xor r8d, r8d
.next:
    cmp r8, r11
    jae .carry
    mov eax, [rdi + r8*4 + 8]
    imul rax, rsi
    add rax, r9
    mov [rdi + r8*4 + 8], eax
    shr rax, 32
    mov r9, rax
    inc r8
    jmp .next
.carry:
    test r9, r9
    jz .done
    cmp r11, 2560
    jae .capacity
    mov [rdi + r11*4 + 8], r9d
    inc r11
    mov [rdi], r11
.done:
    ret
.capacity:
    sub rsp, 8
    call __al_big_bad
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
