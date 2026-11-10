; Original POSIX designation parser. The destination has 64 bytes.
bits 64
default rel

global __al_tz_name:function

section .text.__al_tz_name alloc exec nowrite progbits
__al_tz_name:
    xor ecx, ecx
    xor r8d, r8d
    mov rax, rdi
    cmp byte [rax], 60           ; <
    jne .byte
    inc rax
    mov r8d, 1
.byte:
    movzx edx, byte [rax]
    mov r9d, edx
    or r9d, 32
    sub r9d, 97
    cmp r9d, 25
    jbe .copy
    test r8d, r8d
    jz .end
    cmp edx, 62                  ; >
    je .close
    cmp edx, 43
    je .copy
    cmp edx, 45
    je .copy
    mov r9d, edx
    sub r9d, 48
    cmp r9d, 9
    ja .invalid
.copy:
    cmp ecx, 63
    jae .invalid
    mov [rsi + rcx], dl
    inc rcx
    inc rax
    jmp .byte
.close:
    inc rax
.end:
    cmp ecx, 3
    jb .invalid
    mov byte [rsi + rcx], 0
    ret
.invalid:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
