; Return the address bytes in RAX and their lookup family in EDX.
; IPv4-mapped and IPv4-compatible IPv6 addresses use the embedded IPv4.
bits 64
default rel

global __al_gni_address:function

section .text.__al_gni_address alloc exec nowrite progbits
__al_gni_address:
    movzx edx, word [rdi]
    lea rax, [rdi + 4]
    cmp edx, 2
    je .return
    lea rax, [rdi + 8]
    cmp qword [rax], 0
    jne .return
    mov ecx, [rax + 8]
    cmp ecx, 0xffff0000         ; mapped prefix ::ffff:
    je .embedded
    test ecx, ecx
    jnz .return
    mov ecx, [rax + 12]
    test ecx, ecx              ; :: is native IPv6
    jz .return
    cmp ecx, 0x01000000        ; ::1 is native IPv6
    je .return
.embedded:
    add rax, 12
    mov edx, 2
.return:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
