; Original decimal format-field parser. rdi = cursor, rsi = stride.
; rax = count clamped to INT_MAX+1, rdx = first non-digit.
bits 64
default rel

global __al_fmt_decimal:function

section .text.__al_fmt_decimal alloc exec nowrite progbits
__al_fmt_decimal:
    xor eax, eax
    mov rdx, rdi
    mov r8d, 2147483648
.next:
    cmp esi, 4
    je .wide
    movzx ecx, byte [rdx]
    jmp .digit
.wide:
    mov ecx, [rdx]
.digit:
    sub ecx, 48
    cmp ecx, 9
    ja .done
    add rdx, rsi
    cmp rax, r8
    jae .next
    lea rax, [rax + rax*4]
    lea rax, [rcx + rax*2]
    cmp rax, r8
    jbe .next
    mov rax, r8
    jmp .next
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
