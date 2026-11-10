; Parse a decimal port ending at the given byte. EAX is the port or -1,
; and RDX points to the delimiter on success.
bits 64
default rel

global __al_gai_port:function

section .text.__al_gai_port alloc exec nowrite progbits
__al_gai_port:
    movzx esi, sil
    mov rdx, rdi
    xor eax, eax
.next:
    movzx ecx, byte [rdx]
    cmp ecx, esi
    je .delimiter
    sub ecx, 48
    cmp ecx, 9
    ja .invalid
    imul eax, 10
    add eax, ecx
    cmp eax, 65535
    ja .invalid
    inc rdx
    jmp .next
.delimiter:
    cmp rdx, rdi
    jne .return
.invalid:
    mov eax, -1
.return:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
