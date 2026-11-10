; Original exact environment key match. rdi = entry, rsi = name, rdx = length.
; Return the value address on a match, or NULL.
bits 64
default rel

global __al_env_match:function

section .text.__al_env_match alloc exec nowrite progbits
__al_env_match:
    xor ecx, ecx
.next:
    cmp rcx, rdx
    je .separator
    mov al, [rdi + rcx]
    test al, al
    jz .missing
    cmp al, [rsi + rcx]
    jne .missing
    inc rcx
    jmp .next
.separator:
    cmp byte [rdi + rcx], 61       ; '=' must immediately follow the name
    jne .missing
    lea rax, [rdi + rcx + 1]
    ret
.missing:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
