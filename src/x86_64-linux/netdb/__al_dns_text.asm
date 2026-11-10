; Convert a validated wire name to local ASCII hostname text.
; Return zero if an opaque wire label has no supported text form.
bits 64
default rel

global __al_dns_text:function

section .text.__al_dns_text alloc exec nowrite progbits
__al_dns_text:
    xor r8d, r8d                ; number of labels
.label:
    movzx ecx, byte [rdi]
    inc rdi
    test ecx, ecx
    jz .finish
    test r8d, r8d
    jz .byte
    mov byte [rsi], 46
    inc rsi
.byte:
    movzx eax, byte [rdi]
    cmp eax, 45
    je .copy
    cmp eax, 95
    je .copy
    lea edx, [rax - 48]
    cmp edx, 9
    jbe .copy
    lea edx, [rax - 97]
    cmp edx, 25
    ja .invalid
.copy:
    mov [rsi], al
    inc rsi
    inc rdi
    dec ecx
    jnz .byte
    inc r8d
    jmp .label
.finish:
    test r8d, r8d
    jnz .terminate
    mov byte [rsi], 46          ; the root name
    inc rsi
.terminate:
    mov byte [rsi], 0
    mov eax, 1
    ret
.invalid:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
