; Read the next blank-separated word and advance a mutable line cursor.
; The separator is replaced with a null and # starts a comment.
bits 64
default rel

global __al_gai_word:function

section .text.__al_gai_word alloc exec nowrite progbits
__al_gai_word:
    mov rdx, [rdi]
.skip:
    movzx ecx, byte [rdx]
    test ecx, ecx
    jz .missing
    cmp ecx, 35
    je .missing
    cmp ecx, 32
    je .skip_byte
    cmp ecx, 9
    jb .start
    cmp ecx, 13
    ja .start
.skip_byte:
    inc rdx
    jmp .skip
.start:
    mov rax, rdx
.next:
    inc rdx
    movzx ecx, byte [rdx]
    test ecx, ecx
    jz .finish
    cmp ecx, 35
    je .comment
    cmp ecx, 32
    je .separator
    cmp ecx, 9
    jb .next
    cmp ecx, 13
    ja .next
.separator:
    mov byte [rdx], 0
    inc rdx
    jmp .finish
.comment:
    mov byte [rdx], 0
.finish:
    mov [rdi], rdx
    ret
.missing:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
