; Shift the nonnegative bignum at rdi right by rsi bits. Return whether any removed bit was one.
bits 64
default rel

global __al_big_right_sticky:function

section .text.__al_big_right_sticky alloc exec nowrite progbits
__al_big_right_sticky:
    mov r11, [rdi]
    xor eax, eax
    test r11, r11
    jz .done
    mov r10, rsi
    shr r10, 5
    cmp r10, r11
    jae .remove_all
    mov ecx, esi
    and ecx, 31
    xor r8d, r8d
    xor r9d, r9d
.whole_words:
    cmp r8, r10
    je .partial_word
    or r9d, [rdi + r8*4 + 8]
    inc r8
    jmp .whole_words
.partial_word:
    lea rsi, [rdi + r10*4 + 8]
    sub r11, r10
    mov edx, [rsi]
    shr edx, cl
    shl edx, cl
    xor edx, [rsi]
    or r9d, edx
    xor r8d, r8d
.copy:
    mov eax, [rsi + r8*4]
    lea r10, [r8 + 1]
    cmp r10, r11
    je .top_word
    mov edx, [rsi + r10*4]
    shl rdx, 32
    or rax, rdx
    shr rax, cl
    mov [rdi + r8*4 + 8], eax
    mov r8, r10
    jmp .copy
.top_word:
    shr eax, cl
    mov [rdi + r8*4 + 8], eax
    test eax, eax
    jnz .save_count
    dec r11
.save_count:
    mov [rdi], r11
    xor eax, eax
    test r9d, r9d
    jz .done
    mov eax, 1
.done:
    ret
.remove_all:
    mov qword [rdi], 0
    mov eax, 1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
