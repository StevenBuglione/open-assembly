; Return zero for C, one for C.UTF-8, or minus one for an invalid name.
bits 64
default rel

global __al_locale_value:function

section .text.__al_locale_value alloc exec nowrite progbits
__al_locale_value:
    cmp rsi, 1
    je .c
    cmp rsi, 5
    je .posix
    cmp rsi, 6
    je .alias
    cmp rsi, 7
    jne .invalid
    cmp dword [rdi], 0x54552e43    ; C.UT
    jne .invalid
    cmp word [rdi + 4], 0x2d46     ; F-
    jne .invalid
    cmp byte [rdi + 6], 0x38
    jne .invalid
    jmp .utf8
.alias:
    cmp dword [rdi], 0x74752e43    ; C.ut
    jne .invalid
    cmp word [rdi + 4], 0x3866     ; f8
    jne .invalid
.utf8:
    mov eax, 1
    ret
.c:
    cmp byte [rdi], 0x43
    jne .invalid
    xor eax, eax
    ret
.posix:
    cmp dword [rdi], 0x49534f50    ; POSI
    jne .invalid
    cmp byte [rdi + 4], 0x58
    jne .invalid
    xor eax, eax
    ret
.invalid:
    mov eax, -1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
