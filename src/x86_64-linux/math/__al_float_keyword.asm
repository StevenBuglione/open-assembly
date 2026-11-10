; Original ASCII case-insensitive token match. Returns first byte after the
; keyword, or NULL. rdi = input, rsi = lowercase keyword.
bits 64
default rel

global __al_float_keyword:function

section .text.__al_float_keyword alloc exec nowrite progbits
__al_float_keyword:
    mov rax, rdi
.next:
    mov dl, [rsi]
    test dl, dl
    jz .done
    mov cl, [rax]
    or cl, 32
    cmp cl, dl
    jne .missing
    inc rax
    inc rsi
    jmp .next
.missing:
    xor eax, eax
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
