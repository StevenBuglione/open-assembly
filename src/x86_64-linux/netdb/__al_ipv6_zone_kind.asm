; Return bit zero for interface names on input, bit one on output.
; RDI addresses 16 IPv6 bytes in network order.
bits 64
default rel

global __al_ipv6_zone_kind:function

section .text.__al_ipv6_zone_kind alloc exec nowrite progbits
__al_ipv6_zone_kind:
    movzx eax, word [rdi]
    mov ecx, eax
    and ecx, 0xc0ff
    cmp ecx, 0x80fe            ; fe80::/10
    je .link
    cmp al, 255                ; multicast scope is the second byte's low nibble
    jne .none
    shr eax, 8
    and eax, 15
    cmp eax, 2
    je .link
    cmp eax, 1
    je .return                ; interface-local name accepted on input
.none:
    xor eax, eax
.return:
    ret
.link:
    mov eax, 3
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
