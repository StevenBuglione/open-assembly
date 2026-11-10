; Return the length of a nondecimal interface zone name, or zero.
bits 64
default rel

global __al_ipv6_zone_name:function

section .text.__al_ipv6_zone_name alloc exec nowrite progbits
__al_ipv6_zone_name:
    xor eax, eax
    xor r8d, r8d
.next:
    movzx ecx, byte [rdi + rax]
    test ecx, ecx
    jz .finish
    cmp rax, 15
    jae .invalid
    cmp ecx, 33
    jb .invalid
    cmp ecx, 126
    ja .invalid
    cmp ecx, 37                 ; percent
    je .invalid
    cmp ecx, 47                 ; slash
    je .invalid
    cmp ecx, 58                 ; colon
    je .invalid
    lea edx, [rcx - 48]
    cmp edx, 9
    jbe .advance
    mov r8d, 1
.advance:
    inc rax
    jmp .next
.finish:
    test r8d, r8d
    jz .invalid
    cmp rax, 2
    ja .return
    cmp byte [rdi], 46
    jne .return
    cmp rax, 1
    je .invalid
    cmp byte [rdi + 1], 46
    jne .return
.invalid:
    xor eax, eax
.return:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
