; Return one for RFC 9110 tchar, zero for every other byte.
bits 64
default rel

global __al_http_token:function

section .text.__al_http_token alloc exec nowrite progbits
__al_http_token:
    movzx edi, dil
    cmp edi, 128
    jae .invalid
    mov ecx, edi
    and ecx, 7
    shr edi, 3
    lea rax, [rel token_bits]
    movzx eax, byte [rax + rdi]
    shr eax, cl
    and eax, 1
    ret
.invalid:
    xor eax, eax
    ret

section .rodata.__al_http_token alloc noexec nowrite progbits
token_bits:
    db 0, 0, 0, 0, 0xfa, 0x6c, 0xff, 0x03
    db 0xfe, 0xff, 0xff, 0xc7, 0xff, 0xff, 0xff, 0x57

section .note.GNU-stack noalloc noexec nowrite progbits
