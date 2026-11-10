; Parse four strict decimal octets. EAX is success, EDX is network bytes.
bits 64
default rel

global __al_inet_parse4:function

section .text.__al_inet_parse4 alloc exec nowrite progbits
__al_inet_parse4:
    xor edx, edx
    xor r8d, r8d                ; octet count
.octet:
    movzx ecx, byte [rdi]
    sub ecx, 48
    cmp ecx, 9
    ja .invalid
    inc rdi
    test ecx, ecx
    jz .octet_end              ; a leading zero must be the whole octet
.digit:
    movzx eax, byte [rdi]
    sub eax, 48
    cmp eax, 9
    ja .octet_end
    imul ecx, 10
    add ecx, eax
    cmp ecx, 255
    ja .invalid
    inc rdi
    jmp .digit
.octet_end:
    shl edx, 8
    or edx, ecx
    inc r8d
    cmp r8d, 4
    je .address_end
    cmp byte [rdi], 46
    jne .invalid
    inc rdi
    jmp .octet
.address_end:
    cmp byte [rdi], 0
    jne .invalid
    bswap edx
    mov eax, 1
    ret
.invalid:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
