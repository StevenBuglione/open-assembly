; Measure IPv4 text, or write its bytes to a nonnull destination.
; Return the character count without a terminating null.
bits 64
default rel

global __al_inet_text4:function

section .text.__al_inet_text4 alloc exec nowrite progbits
__al_inet_text4:
    mov r10, rdi
    xor r8d, r8d                ; octet index
    xor r9d, r9d                ; emitted bytes
    mov ecx, 10
.octet:
    test r8d, r8d
    jz .read
    test rsi, rsi
    jz .dot_done
    mov byte [rsi + r9], 46
.dot_done:
    inc r9d
.read:
    movzx eax, byte [r10 + r8]
    xor edx, edx
    div rcx
    mov r11d, edx               ; ones
    cmp eax, 10
    jb .test_tens
    xor edx, edx
    div rcx
    test rsi, rsi
    jz .hundreds_done
    add eax, 48
    mov [rsi + r9], al
.hundreds_done:
    inc r9d
    mov eax, edx
    jmp .tens
.test_tens:
    test eax, eax
    jz .ones
.tens:
    test rsi, rsi
    jz .tens_done
    add eax, 48
    mov [rsi + r9], al
.tens_done:
    inc r9d
.ones:
    test rsi, rsi
    jz .ones_done
    add r11d, 48
    mov [rsi + r9], r11b
.ones_done:
    inc r9d
    inc r8d
    cmp r8d, 4
    jb .octet
    mov eax, r9d
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
